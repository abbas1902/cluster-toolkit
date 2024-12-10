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

GRUB_DEFAULT="/etc/default/grub"

disable_ht_online() {
	if [[ -f /sys/devices/system/cpu/cpu0/topology/thread_siblings_list ]]; then
		for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | awk -F '[^0-9]' '{ print $2 }' | uniq); do
			echo 0 >/sys/devices/system/cpu/cpu${vcpu}/online
		done
	fi
}

update_grub_default() {
	local key=$1
	shift
	local value=$*
	if grep -Eq '^GRUB_CMDLINE_LINUX.*'"$key" $GRUB_DEFAULT; then
		echo "Found boot parameter: $key"
		return 1
	else
		echo "Adding boot parameter: $key"
		local regex="'s/GRUB_CMDLINE_LINUX=\"[^\"]*/& '$key'/'"
		sed -i "$regex" $GRUB_DEFAULT
	fi
}

configure_ht() {
	echo "Disabling hyperthreading"
	local grub_updated=0
	local new_elkernel=1
	if [[ "$new_elkernel" -eq 1 ]]; then
		update_grub_default nosmt && grub_updated=1
	else
		update_grub_default nosmt && grub_updated=1
		update_grub_default nr_cpus="$nr_cpus" && grub_updated=1
	fi
	if [[ "$grub_updated" -eq 1 ]]; then
		update_grub_config
	fi
	# Hot-unplug HT CPU thread siblings
	disable_ht_online
}
