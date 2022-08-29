#!powershell
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

# WANT_JSON
# POWERSHELL_COMMON


# Requires -Module Ansible.ModuleUtils.Legacy

$params = Parse-Args $args;
$result = @{};
Set-Attr $result "changed" $false;

$scvmhost = Get-Attr -obj $params -name scvmhost -failifempty $true -emptyattributefailmessage "missing required argument: scvmhost"
$zielhost = Get-Attr -obj $params -name zielhost -default ''

$name = Get-Attr -obj $params -name name -failifempty $true -emptyattributefailmessage "missing required argument: name"
$cpu = Get-Attr -obj $params -name cpu -default '4'
$memory = Get-Attr -obj $params -name memory -default '4096MB'
$generation = Get-Attr -obj $params -name generation -default 2
$operatingsystem = Get-Attr -obj $params -name operatingsystem -default 'Windows Server 2016 Standard'

$vmpath = Get-Attr -obj $params -name vmpath -default ''
$ha = Get-Attr -obj $params -name highlyavailable -default 'false'
$configtemplate = Get-Attr -obj $params -name configtemplate -default ''
$VHDtemplate = Get-Attr -obj $params -name VHDtemplate -default 'Template.vhdx'
$vmvlan = Get-Attr -obj $params -name vmvlan -default ''
$vmipaddress = Get-Attr -obj $params -name vmipaddress -default ''
$vmhostgroup = Get-Attr -obj $params -name vmhostgroup -default 'All Hosts'
$iso = Get-Attr -obj $params -name iso -default 'SW_DVD9_Win_Server_STD_CORE_2016_64Bit_English_-4_DC_STD_MLF_X21-70526.ISO' #lab iso

$showlog = Get-Attr -obj $params -name showlog -default "false" | ConvertTo-Bool
$state = Get-Attr -obj $params -name state -default "present"

#is needed because awx has no boolean feature
if ($ha -eq "true"){
  $ha = $true
} else{
  $ha = $false
}

if ("poweroff", "present","absent","started","stopped","netchange","isochange" -notcontains $state) {
  Fail-Json $result "The state: $state doesn't exist; State can only be: poweroff, present, absent, started or stopped, netchange, isochange"
}

Function VM-Create {
  #Check If the VM already exists on SCVMM
  $CheckVM = Get-SCVirtualMachine -VMMServer $scvmhost -name $name -ErrorAction SilentlyContinue
  
  if (!$CheckVM) {
    $JobGroupID1 = [Guid]::NewGuid().ToString()
    if (!$configtemplate) { #creates temporary template if var is 0
      $JobGroupID2 = [Guid]::NewGuid().ToString()
      New-SCVirtualScsiAdapter -VMMServer $scvmhost -JobGroup $JobGroupID2 -AdapterID 7 -ShareVirtualScsiAdapter $false -ScsiControllerType DefaultTypeNoType 

      #create hardware template
      New-SCHardwareProfile -VMMServer $scvmhost -Name "tempProfile$JobGroupID2" -Description "Profile used to create a VM/Template" -CPUCount $cpu -MemoryMB $memory -DynamicMemoryEnabled $false -MemoryWeight 5000 -CPUExpectedUtilizationPercent 20 -DiskIops 0 -CPUMaximumPercent 100 -CPUReserve 0 -NumaIsolationRequired $false -NetworkUtilizationMbps 0 -CPURelativeWeight 100 -HighlyAvailable $ha -DRProtectionRequired $false -SecureBootEnabled $true -SecureBootTemplate "MicrosoftWindows" -CPULimitFunctionality $false -CPULimitForMigration $true -CheckpointType Production -Generation 2 -JobGroup $JobGroupID2 
    
      #perp disk
      $VHD = Get-SCVirtualHardDisk -VMMServer $scvmhost | where { $_.Name -eq $VHDtemplate }
      New-SCVirtualDiskDrive -VMMServer $scvmhost -SCSI -Bus 0 -LUN 0 -JobGroup $JobGroupID1 -CreateDiffDisk $false -VirtualHardDisk $VHD -FileName "$name`_Template.vhdx" -VolumeType BootAndSystem 
     
      $HardwareProfile = Get-SCHardwareProfile -VMMServer $scvmhost | where {$_.Name -eq "tempProfile$JobGroupID2"}
      New-SCVMTemplate -Name "tempTemplate$JobGroupID1" -Generation $generation -HardwareProfile $HardwareProfile -JobGroup $JobGroupID1 -NoCustomization -OperatingSystem $operatingsystem
      $configtemplate = "tempTemplate$JobGroupID1"
    }  
    #gets the information needed to deploy vm to host
    $template = Get-SCVMTemplate -All | where { $_.Name -eq $configtemplate }
    $virtualMachineConfiguration = New-SCVMConfiguration -VMTemplate $template -Name $configtemplate
    if (!$zielhost) { 
      $hostRatings = Get-SCVMHostRating -VMConfiguration $virtualMachineConfiguration -VMHostGroup $vmhostgroup -ReturnFirstSuitableHost
      $VMHost = $hostRatings.VMHost #newpart
    } else {
      $VMHost = Get-SCVMHost -VMMServer $scvmhost -ComputerName $zielhost
    }
    $cmdscvmconfiguration = 'Set-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration -VMHost $VMHost'
    if ($vmpath){
        $cmdscvmconfiguration += " -VMLocation $vmpath"
    }
    invoke-expression $cmdscvmconfiguration
    Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration
    
    $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
    $sourceVHD = Get-SCVirtualHardDisk -VMMServer $scvmhost | where { $_.Name -eq $VHDtemplate }
    Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -PinDestinationLocation $false -FileName "$name.vhdx" -StorageQoSPolicy $null -DeploymentOption "UseNetwork" -SourceDisk $sourceVHD
    Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration
    
      # Need to chain these
      $results = invoke-expression 'New-SCVirtualMachine -Name $name -VMConfiguration $virtualMachineConfiguration -Description "" -BlockDynamicOptimization $false -JobGroup $JobGroupID1 -StartAction "NeverAutoTurnOnVM" -StopAction "SaveVM" -OperatingSystem $operatingsystem'
  
           
      
    
      if ($configtemplate -like "temp*" ){
        Remove-SCVMTemplate -VMTemplate $template
      }
      if ($HardwareProfile){
        Remove-SCHardwareProfile -HardwareProfile $HardwareProfile
      }
      $result.msg = "Succesfully created the VM $name on $VMHost"
      $result.vmhost ="$VMHost"
      $result.changed = $true
      } else {
        $result.changed = $false
        if ($configtemplate -like "temp*" ){
          Remove-SCVMTemplate -VMTemplate $template
        }
        if ($HardwareProfile){
          Remove-SCHardwareProfile -HardwareProfile $HardwareProfile
        }
      }
    }

    Function VM-Netchange{
      $CheckVM = Get-SCVirtualMachine -VMMServer $scvmhost -name $name -ErrorAction SilentlyContinue
      if ($CheckVM) {
        $VM = Get-SCVirtualMachine -Name $name   #gets the information of the vm
        #Adding Network Adapter
        if ($vmvlan) {
          New-SCVirtualNetworkAdapter -VM $name -MACAddressType "Static" -Synthetic
          $vmvlan = Get-SCVMNetwork | where { $_.Name -eq $vmvlan}
          $vmadapter = Get-SCVirtualNetworkAdapter -VM $name
          Set-SCVirtualNetworkAdapter -VirtualNetworkAdapter $vmadapter -VirtualNetwork "DEFAULT" -VMNetwork $vmvlan
  
          if ($vmipaddress){
            $NIC = Get-SCVirtualNetworkAdapter -VMMServer $scvmhost -VM $name
            Set-SCVirtualNetworkAdapter -VMMServer $scvmhost -VirtualNetworkAdapter $VM.VirtualNetworkAdapters[($NIC.SlotID)] -IPv4AddressType Static -IPv4Addresses $vmipaddress
          }
        }
        $result.msg = "Succesfully set the VM Network adapter on the VM $name with $vmvlan.Name and $vmipaddress"
        $result.changed = $true
        } else {
         $result.changed = $false
       }
    }

    Function VM-Isochange{
      $CheckVM = Get-SCVirtualMachine -VMMServer $scvmhost -name $name -ErrorAction SilentlyContinue
      if ($CheckVM) {
        $VM = Get-SCVirtualMachine -Name $name   #gets the information of the vm
        if ($iso) {
        New-SCVirtualDVDDrive -VM $VM -Bus 0 -LUN 1
        $DVDDrive = Get-SCVirtualDVDDrive -VM $VM
        $iso = Get-SCISO -VMMServer $scvmhost | where { $_.Name -eq $iso}
        Set-SCVirtualDVDDrive -VirtualDVDDrive $DVDDrive -ISO $iso -Link
        }
        $result.msg = "Succesfully set the ISO $iso.Name on the VM $name"
        $result.changed = $true
        } else {
         $result.changed = $false
       }
    }
      

    Function VM-Delete {
      $CheckVM = Get-SCVirtualMachine -VMMServer $scvmhost -name $name -ErrorAction SilentlyContinue

      if ($CheckVM) {
        $cmd="Remove-SCVirtualMachine -VM $name -Force"
        $results = invoke-expression $cmd
        $result.changed = $true
        } else {
         $result.changed = $false
       }
     }

     Function VM-Start {
      $CheckVM = Get-SCVirtualMachine -VMMServer $scvmhost -name $name -ErrorAction SilentlyContinue

      if ($CheckVM) {
        $cmd="Start-SCVirtualMachine -VM $name"
        $results = invoke-expression $cmd
        $result.msg = "Succesfully started VM $name"
        $result.changed = $true
        } else {
         Fail-Json $result "The VM: $name; Doesn't exists please create the VM first"
       }
     }

     Function VM-Poweroff {
      $CheckVM = Get-SCVirtualMachine -VMMServer $scvmhost -name $name -ErrorAction SilentlyContinue

      if ($CheckVM) {
        $cmd="Stop-SCVirtualMachine -VM $name -Force"
        $results = invoke-expression $cmd
        $result.changed = $true
        } else {
         Fail-Json $result "The VM: $name; Doesn't exists please create the VM first"
       }
     }

     Function VM-Shutdown {
      $CheckVM = Get-SCVirtualMachine -VMMServer $scvmhost -name $name -ErrorAction SilentlyContinue

      if ($CheckVM) {
        $cmd="Stop-SCVirtualMachine -VM $name"
        $results = invoke-expression $cmd
        $result.changed = $true
        } else {
         Fail-Json $result "The VM: $name; Doesn't exists please create the VM first"
       }
     }

     Try {
      switch ($state) {
        "present" {VM-Create}
        "absent" {VM-Delete}
        "started" {VM-Start}
        "stopped" {VM-Shutdown}
        "poweroff" {VM-Poweroff}
        "netchange" {VM-Netchange}
        "isochange" {VM-Isochange}
      }
      
      Exit-Json $result;
      } Catch {
        Fail-Json $result $_.Exception.Message
      }