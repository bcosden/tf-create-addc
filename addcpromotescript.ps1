<#
    .SYNOPSIS
        Promote Azure VM to Primary AD Domain Controller.
    .DESCRIPTION
        
#>
[CmdletBinding(DefaultParameterSetName = "Standard")]
param(
    [string]
    [ValidateNotNullOrEmpty()]
    $vm_username,
    [ValidateNotNullOrEmpty()]
    $vmpassword,
    [ValidateNotNullOrEmpty()]
    $domain,
    [ValidateNotNullOrEmpty()]
    $subnet_storage,
    [ValidateNotNullOrEmpty()]
    $addcsitename
)

#Assign RAW disk and add drive letter
Get-Disk | Where partitionstyle -eq ‘raw’ | `
  Initialize-Disk -PartitionStyle MBR -PassThru | `
  New-Partition -AssignDriveLetter -UseMaximumSize | `
  Format-Volume -FileSystem NTFS -NewFileSystemLabel “ADDCDATA” -Confirm:$false

#Install ADDS
Install-windowsfeature AD-domain-services -IncludeManagementTools

#Create Primary ADDC
Install-ADDSForest `
 -CreateDnsDelegation:$false `
 -DatabasePath "F:\NTDS" `
 -LogPath "F:\NTDS" `
 -SysvolPath "F:\SYSVOL" `
 -DomainName $domain `
 -InstallDns:$true `
 -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText $vmpassword -Force) `
 -NoRebootOnCompletion `
 -Force:$true

#Allow the main subnet access to the default site
New-ADReplicationSubnet -Name $subnet_storage -Site $addcsitename

Restart-Computer -Force
