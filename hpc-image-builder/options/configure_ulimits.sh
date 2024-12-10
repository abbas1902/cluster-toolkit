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

readonly LIMITSD_CONF="/etc/security/limits.d/98-google-hpc-image.conf"
readonly LIMITS_CONF="/etc/security/limits.conf"

update_limits() {
	local item=$1
	local value=$2
	echo "Updating limits item=$item, value=$value"
	local line="\*    -    $item    $value"
	local regex="'/^\s*\*.+'$item'.*$/d'"
	sed -Ei $regex $LIMITS_CONF
	echo "$line" ">>" $LIMITS_CONF
}

configure_limits() {
	if [[ -d "$(dirname "${LIMITSD_CONF}")" ]]; then
		echo "98-google-hpc-image.conf already present"
		# limits.d changes require rebooting
	else
		# If limits.d is not supported
		echo "Applying limits.conf"
		update_limits nproc unlimited
		update_limits memlock unlimited
		update_limits stack unlimited
		update_limits nofile 1048576
		update_limits cpu unlimited
		update_limits rtprio unlimited
	fi
	ulimit -a
}
