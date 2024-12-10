# HPC Toolkit Image Builder Blueprint

This blueprint automates the creation of a customized Rocky Linux 8 image optimized for high-performance computing (HPC) workloads on Google Cloud. It leverages the HPC Toolkit and Packer to streamline the image building process. For more information about the HPC VM Image visit: https://cloud.google.com/compute/docs/instances/create-hpc-vm

Subdirectories:
- `\options`: Has several configuration scripts which can be used to apply tunings for the image.
- `\placed_files`: Contains files intended to be place in specific locations such as the tuned profile, a file to disable gvnic-coalescing and one to set system ulimits.
- `\scripts`: This subdirectory has all of the scripts that run during the image creation process (such as installing packages).
- `\services`: Dedicated for the two systemd services that run for the image.
    - `google-hpc-firstrun`: This script sets up the image for HPC by installing MPI, optimizing performance, and configuring network settings based on metadata.
    - `google-hpc-multiqueue`: This script optimizes network settings for HPC workloads. It does this by adjusting network queues and IRQ affinities.

# How to run this blueprint
After setting all the relevant fields in the `vars` section of the blueprint, you can execute the creation of the image with the following command:
```
./gcluster deploy hpc-image-builder/hpc-image.yaml
```
Upon completion the image will be stored under the value of `vars.output_image_name` in your GCP project.
