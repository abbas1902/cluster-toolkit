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

update_grub_default() {
	local key=$1
	shift
	local value=$*
	if grep -Eq '^GRUB_CMDLINE_LINUX.*'"$key" $GRUB_DEFAULT; then
		echo "Found boot parameter: $key"
		return 1
	else
		echo "Adding boot parameter: $key"
		local regex='s/GRUB_CMDLINE_LINUX=\"[^\"]*/& '$key'/'
		sed -i "$regex" $GRUB_DEFAULT
	fi
}

configure_mitigations() {
	echo "Disabling CPU mitigations"
	local grub_updated=0
	local new_elkernel=1
	if [[ "$new_elkernel" -eq 1 ]]; then
		update_grub_default mitigations=off && grub_updated=1
	else
		update_grub_default spectre_v2=off
		update_grub_default nopti
		update_grub_default spec_store_bypass_disable=off
		grub_updated=1
	fi
	if [[ "$grub_updated" -eq 1 ]]; then
		update_grub_config
	fi
}
