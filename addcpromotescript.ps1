<#
    .SYNOPSIS
        Promote Azure VM to Primary AD Domain Controller.
    .DESCRIPTION
        
#>
[CmdletBinding(DefaultParameterSetName = "Standard")]
param(
    [string]
    [ValidateNotNullOrEmpty()]
    $vmpassword,
    [ValidateNotNullOrEmpty()]
    $addcdomain
)

Write-Log 'addcdomain: $addcdomain'

filter Timestamp {"$(Get-Date -Format o): $_"}

function
Write-Log($message) {
    $msg = $message | Timestamp
    Write-Output $msg
}

Try
{
    #Assign RAW disk and add drive letter
    $addisk = Get-Disk -Number 2
    Write-Log 'Get-Disk: $addisk'

    Initialize-Disk -FriendlyName $addisk.FriendlyName -PartitionStyle MBR -PassThru
    Write-Log 'Initialize Disk'

    New-Partition -DiskNumber $addisk.Number -AssignDriveLetter -UseMaximumSize
    Write-Log 'Parition Disk'

    Format-Volume -DriveLetter F -FileSystem NTFS -NewFileSystemLabel 'ADDCDATA' -Confirm:$false
    Write-Log 'Format Disk'

    #Install ADDS
    Install-windowsfeature AD-domain-services -IncludeManagementTools
    Write-Log 'Install ADDS'

    #Create Primary ADDC
    Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath 'F:\NTDS' -LogPath 'F:\NTDS' -SysvolPath 'F:\SYSVOL' -DomainName $addcdomain -InstallDns:$true -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText $vmpassword -Force) -Force:$true
    Write-Log 'Create Forest'
}
catch {
    Write-Error $_
}
