#!/bin/bash
# Copyright 2021 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is for the startup firstrun to configure software environment.
# It reads metadata from its compute engine metadata server and conducts the
# following operations:
# - MPI environment set up: use google_install_mpi to install MPI software
# - MPI tuning set up: use google_mpi_tuning to apply system tunings for getting
#  better performance for MPI application.

set -x -e -o pipefail

URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
MAXTIME=1
FIRSTRUN="/.google_hpc_firstrun"

function get_attributes() {
	# Check if the metadata server is up.
	attempts=8
	for i in $(seq 1 $attempts); do
		echo "Checking connectivity to metadata server - attempt #$((i)) of $attempts"
		sleep $((2 ** i))

		exit_code=0
		curl --max-time $MAXTIME --retry 5 --retry-connrefused -f -H Metadata-Flavor:Google ${URL}/ || exit_code=$?
		if [[ $exit_code -eq 0 ]]; then
			break
		fi

		echo "Metadata server is not up yet after attempt $i/$attempts (exit_code=$exit_code)..."
	done

	if [[ $exit_code -ne 0 ]]; then
		echo "Metadata server is not up after $attempts attempts."
		exit "$exit_code"
	fi

	INSTALL_INTELMPI="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${URL}/google_install_intelmpi || true)"
	DISABLE_AUTOMATIC_UPDATES="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${URL}/google_disable_automatic_updates || true)"
	MULTIQUEUE_OPT="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${URL}/multiqueue || true)"
	GVNIC="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${URL}/enable-gvnic || true)"
	TUNED_ADM_PROFILE="$(curl --max-time $MAXTIME -f -s -H Metadata-Flavor:Google ${URL}/hpc_tuned_profile  || true)"
}

function disable_automatic_updates() {
	source /etc/hpc-image-builder/google_disable_automatic_updates.sh
	if [[ ${DISABLE_AUTOMATIC_UPDATES} == "TRUE" ]]; then
		echo "Disable automatic updates: google_disable_automatic_updates ${DISABLE_AUTOMATIC_UPDATES}"
		google_disable_automatic_updates
	else
		echo "Automatic updates were not disabled through metadata."
	fi
}

function set_tuned_profile() {
	source /etc/hpc-image-builder/options/configure_hpc_profile.sh
		if [[ ${TUNED_ADM_PROFILE} == "TRUE" ]]; then
		echo "Setting tuned profile to google-hpc-compute"
		configure_hpcprofile
	else
		echo "Tuned profile was not changed"
	fi
}

function install_intelmpi() {
	source /etc/hpc-image-builder/google_install_intelmpi.sh
	if [[ ${INSTALL_INTELMPI} ]]; then
		echo "Install MPI environment: google_install_intelmpi ${INSTALL_INTELMPI}"
		google_install_intelmpi "${INSTALL_INTELMPI}"
	else
		echo "No MPI environment configured through metadata."
	fi
}


function set_mulitqueue() {
	if [[ ${MULTIQUEUE_OPT} == "TRUE" ]]; then
		echo "Disable google_set_multiqueue."
		sed -i 's/^\(set_multiqueue\s*=\s*\).*$/\1false # superseded by google_hpc_multiqueue/' /etc/default/instance_configs.cfg
	fi
}
function enable_gvnic() {
	if [[ ${GVNIC} == "TRUE" ]]; then
		# locate the gve driver version
		local_gve_version="$(dkms status gve | awk -F'[,:/]' '{print $2}')"
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
}

rm -f ${FIRSTRUN}
echo "Google HPC startup firstrun operation."
get_attributes
disable_automatic_updates
install_intelmpi
set_mulitqueue
enable_gvnic
