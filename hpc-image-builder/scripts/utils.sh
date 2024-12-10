#!/bin/bash
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

readonly WORKING_DIR=/root/mpi-tuning

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
  rm -rf "${WORKING_DIR:?}/"
  rm -f ~/.bash_history && history -c
}
