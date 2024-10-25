#!/bin/sh
# Copyright 2024 "Google LLC"
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


readonly SYSTEMD_UNIT_ROOT=/lib/systemd/system
readonly WORKING_DIR=/root/mpi-tuning
MAXTIME=1

readonly METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance"

#########
# Setup #
#########

trap notify_fail ERR
function notify_fail() {
  trap "Image build failure: failed to setup HPC VM image" EXIT
}

function clear_shadow_locks() {
  # clears out stale shadow-utils locks in /etc/
  filenames=('group' 'gshadow' 'passwd' 'shadow' 'subgid' 'subuid')
  for f in "${filenames[@]}"; do
    if [[ -f "/etc/${f}.lock" ]]; then
      echo "find /etc/${f}.lock and rm it"
      rm "/etc/${f}.lock"
    fi
  done
}

function setup_instance() {
  echo "Setup instance."

  # disable google-guest-agent service
  # google-guest-agent will insert user accounts and keys
  # systemctl stop google-guest-agent.service

  # clean up the lock files
  clear_shadow_locks

  echo "Create working directory."
  mkdir -p ${WORKING_DIR}
}

#####################
# Instance metadata #
#####################

function wait_for_metadata_server() {
  # Check if the metadata server is up.
  attempts=8
  for i in $(seq 1 $attempts); do
    echo "Checking connectivity to metadata server - attempt #$((i)) of $attempts"
    sleep $((2 ** i))

    exit_code=0
    get_instance_metadata_value "attributes/" || exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
      break
    fi

    echo "Metadata server is not up yet after attempt $i/$attempts (exit_code=$exit_code)..."
  done

  if [[ $exit_code -ne 0 ]]; then
    echo "Metadata server is not up after $attempts attempts."
    exit $exit_code
  fi
}

function get_instance_metadata_value() {
  key="$1"

  value=$(curl --max-time $MAXTIME --retry 5 --retry-connrefused -f -H 'Metadata-Flavor:Google' "${METADATA_URL}/${key}")

  TUNED_ADM_PROFILE="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${METADATA_URL}/attributes/google_mpi_tuning || true)"

	INSTALL_INTELMPI="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${METADATA_URL}/attributes/google_install_intelmpi || true)"
	
  DISABLE_AUTOMATIC_UPDATES="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${METADATA_URL}/attributes/google_disable_automatic_updates || true)"

  MULTIQUEUE_OPT="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${METADATA_URL}/attributes/multiqueue-opt|| true)"
  
  GVNIC="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${METADATA_URL}/attributes/enable-gvnic || true)"

  echo "MPI TUNE IS $TUNED_ADM_PROFILE"
  if [[ ! ${value} ]]; then
    echo "'${key}' instance metadata entry not found"
    return
  fi

  echo "${value}"
}

#############################
# Disable automatic updates #
#############################

function disable_automatic_updates() {
	if [[ ${DISABLE_AUTOMATIC_UPDATES} == "TRUE" ]]; then
		echo "Disable automatic updates: google_disable_automatic_updates ${DISABLE_AUTOMATIC_UPDATES}"
		google_disable_automatic_updates ${DISABLE_AUTOMATIC_UPDATES}
	else
		echo "Automatic updates were not disabled through metadata."
	fi
}

######################
# Install intel MPI  #
######################
function install_intelmpi() {
	if [[ ${INSTALL_INTELMPI} ]]; then
		echo "Install MPI environment: google_install_intelmpi ${INSTALL_INTELMPI}"
		google_install_intelmpi ${INSTALL_INTELMPI}
	else
		echo "No MPI environment configured through metadata."
	fi
}

#################
#  Post Build   #
#################

function cleanup() {
  # systemd-machine-id-setup will setup on next run
  echo "uninitialized" > /etc/machine-id
  # delete/truncate /var/log files
  rm -f /var/log/dmesg*
  rm -rf /var/log/tuned
  truncate -s 0 /var/log/boot.log
  truncate -s 0 /var/log/audit/audit.log
  truncate -s 0 /var/log/lastlog
  truncate -s 0 /var/log/maillog
  truncate -s 0 /var/log/firewalld
  truncate -s 0 /var/log/secure
  truncate -s 0 /var/log/wtmp
  touch /.google_hpc_firstrun
  # Remove Packages with Dependencies Using Yum
  yum autoremove -y
  # Clear journalctl
  journalctl --flush
  journalctl --vacuum-time=1s
  # cleanup yum logs
  yum clean all
  # delete yum cache
  rm -rf /var/cache/yum
  # clean up ssh_host_*
  shred --remove /etc/ssh/ssh_host_*
  truncate -s 0 /var/log/messages
  rm -rf "${WORKING_DIR}/"
  rm -f ~/.bash_history && history -c
}

function postinstall() {
  if [[ ${MULTIQUEUE_OPT} == "TRUE" ]]; then
    echo "Disable google_set_multiqueue."
    sed -i 's/^\(set_multiqueue\s*=\s*\).*$/\1false # superseded by google_hpc_multiqueue/' /etc/default/instance_configs.cfg
  fi

  if [[ ${GVNIC} == "TRUE" ]]; then
    # locate the gve driver version
    local_gve_version="$(dkms status gve | awk -F'[,:/]' {'print $2'})"
    if [[ -z ${local_gve_version// } ]]; then
      echo "Unable to locate the version of the gve DKMS module."
    fi

    # let dkms install gve driver
    dkms install -m gve -v "${local_gve_version}"

    # check if the oot gve driver has been selected
    local_check1=$(grep gve /lib/modules/"$(uname -r)"/modules.dep | grep extra)
    if [[ -z ${local_check1} ]]; then
      echo "DKMS gve driver not selected in depmod."
    fi

    # check if gve driver has the right alias
    # PCI Vendor ID [1AE0] = Google, Inc.
    # PCI Device ID [0042] = Compute Engine Virtual Ethernet [gVNIC]
    local_check2=$(grep gve /lib/modules/"$(uname -r)"/modules.alias | grep 'v0*1AE0d0*0042')
    if [[ -z ${local_check2} ]]; then
      echo "DKMS gve driver alias not set."
    fi
  fi

  # check if home directory is empty
  home_check="$(ls -A /home || true)"
  if [[ ! -z "${home_check}" ]]; then
    echo "/home directory is not empty."
  fi
}
