#!/usr/bin/python
# -*- coding: utf-8 -*-

# This file is part of Ansible
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.

# this is a windows documentation stub. actual code lives in the .ps1
# file of the same name

#https://github.com/glenndehaan/ansible-win_hyperv_guest

DOCUMENTATION = '''
---
module: win_scvmm_guest
version_added: "2.6"
short_description: Adds, deletes, configures and performs power functions on Hyper-V VM's on SCVMM.
description:
    - Adds, deletes, configures and performs power functions on Hyper-V VM's on SCVMM.
options:
  name:
    description:
      - Name of VM
    required: true
  state:
    description:
      - State of VM
    required: false
    choices:
      - poweroff #push button
      - present
      - absent
	    - started
	    - stopped
      - netchange
      - isochange
    default: present
  scvmhost:
    description:
      - Manageserver to configure VM from
    required: true
    default: null
  cpu:
    description:
      - Sets the amount of cpus for the VM.
    required: false
    default: 4
  memory:
    description:
      - Sets the amount of memory for the VM.
    required: false
    default: 4096MB
  generation:
    description:
      - Specifies the generation of the VM
    required: false
    default: 2
  operatingsystem:
    description:
      - Specify the operationsystem which will be installed there is just 2016 at the moment
    require: false
    default: Windows Server 2016 Standard
  vmpath:
    description:
      - Specify path of the VM folder and places the VHD/VHDX in sub folders, if location spcified in the choosen HyperV will be used.
    require: false
    default: null
  ha:
    descritption:
      - is needed if the machine is going to be deployed to a cluster oder high availability system 
    require: false
    default: false
  configtemplate:
    descritption:
      - if configtemplate is used (createdhardware configuration template in scvmm) all the previes settings will not be used
    require: false
    default: null
  VHDtemplate:
    descritption:
      - syspreped windows disk which will be copied for the new virtual machine.
    require: true
    default: null
  vmvlan:
    descritption:
      - vlan for the network adapter
    require: false
    default: null
  vmipaddress:
    descritption:
      - ip adress for the vm
    require: false
    default: null
  vmhostgroup:
    descritption:
      - define in which vmhostgroup the vm should be deployed
    require: false
    default: null
  iso:
    description:
      - connects this iso after boot up
    required: false
    default: null

    
'''

EXAMPLES = '''
# Create VM
- name: "Create New VM {{ name }}"
  win_scvmm_guest:
    scvmhost: scvmmserverfqdn #bleibt immer gleich
    zielhost:  #if empty scvmm chooses the best fitting host, the zeilhost should be in the vmhostgroup u choose later 
    name: zrhhnop11w
    generation: 2
    memory: 12288
    cpu: 4
    state: present
    vmpath: 'D:\Hyper-V\VM' #if note set it will use the vmhosts default location  ##uses the high aviability param 'C:\ClusterStorage\Volume2\Hyper-V\VM',D:\Hyper-V\VM
    highlyavailable: false
    #todo disksize_c= 80GB
    operatingsystem: 'Windows Server 2016 Standard' #is only used if no configtemplate is set
    #configtemplate: "Template" #can be set if there is a template for the specs
    VHDtemplate: 'WinServ2016_Standard_22_03_2022.vhdx'
    vmvlan: "VMNET_0050_DMZ"
    vmipaddress: '192.168.50.60'
    vmhostgroup: 'Datacenter' #defines in wich host group the vm should be in. is not used if zeilhost is set

# Add iso to VM    
- name: "add iso to VMs"
  win_scvmm_guest:
    scvmhost: "{{ scvmhost }}"
    name: "{{ name }}"
    state: isochange
    iso: 'WinSrv_Standard_2016_13.02.2020.ISO'

# Add network adapter and IP to VM
- name: "add vm adapter and ad ip to VM"
  win_scvmm_guest:
    scvmhost: "{{ scvmhost }}"
    name: "{{ name }}"
    state: netchange
    vmvlan: "{{ vmvlan }}"
    vmipaddress: "{{ vmipaddress }}"

- name: "Power on VM"
  win_scvmm_guest:
    scvmhost: "{{ scvmhost }}"
    name: "{{ name }}"
    state: started
'''

ANSIBLE_METADATA = {
    'status': ['preview'],
    'supported_by': 'community',
    'metadata_version': '1.1'
}
