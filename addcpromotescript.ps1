<#
    .SYNOPSIS
        Promote Azure VM to Primary AD Domain Controller.
    .DESCRIPTION
        
#>
[CmdletBinding(DefaultParameterSetName = "Standard")]
param(
    [string]
    [ValidateNotNullOrEmpty()]
    $vmuser,
    [ValidateNotNullOrEmpty()]
    $vmpassword,
    [ValidateNotNullOrEmpty()]
    $addcdomain,
    [ValidateNotNullOrEmpty()]
    $subnet_addc,
    [ValidateNotNullOrEmpty()]
    $defaultsitename

)

filter Timestamp {"$(Get-Date -Format o): $_"}

function
Write-Log($message) {
    $msg = $message | Timestamp
    Write-Output $msg
}

Try
{
    #Wait for some time to ensure PDC is up
    Start-Sleep -s 300
    Write-Log 'Waking up....'

    #Assign RAW disk and add drive letter
    $addisk = Get-Disk -Number 2
    Write-Log 'Get-Disk'

    Initialize-Disk -FriendlyName $addisk.FriendlyName -PartitionStyle MBR -PassThru
    Write-Log 'Initialize Disk'

    New-Partition -DiskNumber $addisk.Number -AssignDriveLetter -UseMaximumSize
    Write-Log 'Parition Disk'

    Format-Volume -DriveLetter F -FileSystem NTFS -NewFileSystemLabel 'ADDCDATA' -Confirm:$false
    Write-Log 'Format Disk'

    #Install ADDS
    Install-windowsfeature AD-domain-services -IncludeManagementTools
    Write-Log 'Install ADDS'
    
    #Format the user and password into domain style and as a credential
    $domainval = $addcdomain.Split("{.}")[0]
    $domainval = $domainval.ToUpper() 
    $domainuser = $domainval + "\" + $vmuser
    $pword = ConvertTo-SecureString -String $vmpassword -AsPlainText -Force
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $domainuser, $pword

    #Create Secondary ADDC
    Install-ADDSDomainController -CriticalReplicationOnly -CreateDnsDelegation:$false -Credential $cred -DatabasePath "F:\NTDS" -LogPath "F:\NTDS" -SysvolPath "F:\SYSVOL" -DomainName $addcdomain -InstallDns:$true -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText $vmpassword -Force) -Force:$true
    Write-Log 'Added Domain Controller'
}
catch {
    Write-Error $_
}
