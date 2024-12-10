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

readonly NIC="eth0"

configure_interrupt_coalescing() {
	echo "Modifying Interrupt Coalesce settings"
	DRIVER_NAME=$(ethtool -i ${NIC} | sed -n "s/^driver:\s*//p")
	if [[ $DRIVER_NAME == 'gve' ]]; then
		echo "Setting values for rx-usecs and tx-usecs to 0"
		ethtool -C ${NIC} rx-usecs 0 &>/dev/null
		ethtool -C ${NIC} tx-usecs 0 &>/dev/null
	else
		echo "gVNIC driver not enabled"
	fi
}
