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

import json
import subprocess
import time
import unittest
import re
from ssh import SSHManager
from deployment import Deployment

class Test(unittest.TestCase):  # Inherit from unittest.TestCase
    def __init__(self, deployment):
        super().__init__()  # Call the superclass constructor
        self.deployment = deployment
        self.ssh_manager = None
        self.ssh_client = None

    def run_command(self, cmd: str) -> subprocess.CompletedProcess:
        res = subprocess.run(cmd, shell=True, text=True, check=True,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return res

    def setUp(self):
        self.addCleanup(self.clean_up)
        self.deployment.deploy()
        time.sleep(120)

    def clean_up(self):
        self.deployment.destroy()

class SlurmTest(Test):
    # Base class for Slurm-specific tests.
    def ssh(self, hostname):
        self.ssh_manager = SSHManager()
        self.ssh_manager.setup_connection(hostname, self.deployment.project_id, self.deployment.zone)
        self.ssh_client = self.ssh_manager.ssh_client
        self.ssh_client.connect("localhost", self.ssh_manager.local_port, username=self.deployment.username, pkey=self.ssh_manager.key)

    def close_ssh(self):
        if self.ssh_manager:
            self.ssh_manager.close()

    def setUp(self):
        super().setUp()
        hostname = self.get_login_node()
        self.ssh(hostname)

    def clean_up(self):
        super().clean_up()
        self.close_ssh()

    def get_login_node(self):
        login_name = re.sub(r"^[^a-z]*|[^a-z0-9]", "", self.deployment.deployment_name)[:10]
        return login_name+"-slurm-login-001"

    def assert_equal(self, value1, value2, message=None):
        if value1 != value2:
            if message is None:
                message = f"Assertion failed: {value1} != {value2}"
            raise AssertionError(message)

    def get_nodes(self):
        nodes = []
        stdin, stdout, stderr = self.ssh_client.exec_command("scontrol show node| grep NodeName")
        for line in stdout.read().decode().splitlines():
            nodes.append(line.split()[0].split("=")[1])
        return nodes
