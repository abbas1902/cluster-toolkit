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

# check active tuned profile
GRUB_DEFAULT="/etc/default/grub"
SYSCTL_CONF="/etc/sysctl.conf"

get_active_profile() {
	ACTIVE_PROFILE=$(tuned-adm active | awk {'print $4'})
	echo "Current tuned profile ${ACTIVE_PROFILE}"
}

update_sysctl() {
	local key=$1
	shift
	local value=$*
	echo "Updating sysctl key=$key, value=$value"
	touch $SYSCTL_CONF
	sed -i -E "s/^\s*$key\s*=.*$/$key = $value/g" $SYSCTL_CONF
	if ! grep -Fq "$key" "$SYSCTL_CONF"; then
		echo "sysctl $key not found, appending to $SYSCTL_CONF"
		echo "$key = $value" >>$SYSCTL_CONF
	fi
}

configure_tcpmem() {
	if [[ ${ACTIVE_PROFILE} == ${HPC_PROFILE} ]]; then
		echo "Skip tcpmem tuning: applied in ${HPC_PROFILE} tuned profile"
	else
		echo "Updating sysctl: TCP memory"
		update_sysctl net.ipv4.tcp_rmem 4096 87380 16777216
		update_sysctl net.ipv4.tcp_wmem 4096 16384 16777216
		sysctl -p
	fi
}
