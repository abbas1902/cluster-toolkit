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

HPC_PROFILE="google-hpc-compute-throughput"
HPC_PROFILE_PATH="/usr/lib/tuned/google-hpc-compute-throughput/tuned.conf"

configure_hpcprofile_throughput() {
	echo "Installing ${HPC_PROFILE} profile"
	mkdir -p "$(dirname "${HPC_PROFILE_PATH}")"
	tuned-adm profile ${HPC_PROFILE}
	ACTIVE_PROFILE=$(tuned-adm active | awk '{print $4}')
	echo "Current tuned profile ${ACTIVE_PROFILE}"
}
