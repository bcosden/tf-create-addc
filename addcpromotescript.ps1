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
$addisk = Get-Disk -Number 2

Set-Content -Path 'C:\file.txt' -Value $addisk
Set-Content -Path 'C:\file2.txt' -Value $error

Initialize-Disk -FriendlyName $addisk.FriendlyName -PartitionStyle MBR -PassThru

New-Partition -DiskNumber $addisk.Number -AssignDriveLetter -UseMaximumSize

Format-Volume -DriveLetter F -FileSystem NTFS -NewFileSystemLabel “ADDCDATA” -Confirm:$false

#Install ADDS
Install-windowsfeature AD-domain-services -IncludeManagementTools

#Create Primary ADDC
Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "F:\NTDS" -LogPath "F:\NTDS" -SysvolPath "F:\SYSVOL" -DomainName $domain -InstallDns:$true -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText $vmpassword -Force) -NoRebootOnCompletion -Force:$true

Restart-Computer -Force
