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

EL8_RPM_LIST=(
"gcc-gfortran"
"gcc-toolset-12"
"Lmod"
"htop"
"hwloc"
"hwloc-devel"
"kernel"
"kernel-devel"
"libfabric"
"libXt"
"ltrace"
"nfs-utils"
"numactl"
"numactl-devel"
"papi"
"pciutils"
"pdsh-rcmd-ssh"
"perf"
"redhat-lsb-core"
"redhat-lsb-cxx"
"rsh"
"screen"
"strace"
"wget"
"zsh"
)

function install_rdma_driver() {
  dnf install https://depot.ciq.com/public/files/gce-accelerator/irdma-kernel-modules-el8-x86_64/irdma-repos.rpm -y
  dnf update -y
  dnf install kmod-idpf-irdma rdma-core libibverbs-utils librdmacm-utils infiniband-diags perftest -y
}

function install_packages() {
	dnf check-update || true
	dnf update -y
	dnf install -y epel-release
	dnf config-manager --set-enabled powertools
	dnf groupinstall -y "Development tools"
  install_rdma_driver
  for package in "${EL8_RPM_LIST[@]}"; do
    # install the package
    dnf install -y "${package}"
    # verify if the package has been installed
    rpm -qi "${package}"
  done
}
