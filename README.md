# Original Code:
Repo: https://github.com/glenndehaan/ansible-win_hyperv_guest created by https://github.com/glenndehaan
Heavily modified to fit SCVMM by https://github.com/andrihitz project for https://github.com/open-circle-ltd


# Ansible Windows SCVMM Guest Module

An ansible module to control Hyper-V VM's through SCVMM with ansible

## Structure
- Python
- YAML
- Powershell

## Basic Usage
- Install Ansible 2.8
- Run `pip install pywinrm`
create your playbook with the the documentary at library/win_scvmm_guest.py 

## Notes
- This module has been tested on Debian 11 running Ansible 2.8 (System Center 2016 Virtual Machine Manager (SCVMMM 2016) 40.1662.0, Windows Server 2016)
- Run the following script on the Windows machine in order for Ansible to be able to connect to the machine: https://github.com/ansible/ansible/blob/devel/examples/scripts/ConfigureRemotingForAnsible.ps1

## License

MIT
