<#
 .SYNOPSIS
 Imports\Exports registry key from\to .reg file, query, clear registry key.

 .DESCRIPTION
 Imports\Exports registry key from\to .reg file, query, clear registry key.

 .NOTES
 Registry key is restored from .reg file or backup to .reg file using SAME paths on each of specified hosts.

 .PARAMETER compnames
 Specifies hostnames where you want to perform import\export operations.

  .PARAMETER backup
 Specifies whether to export registry key to .reg file.

 .PARAMETER restore
 Specifies whether to import registry key from .reg file.

  .PARAMETER check
 Specifies whether to query registry key on specified host.

   .PARAMETER clear
 Specifies whether to clear registry key content on specified host.

 .PARAMETER RegKeypath
 Specifies path to registry key in Powershell PSDrive format. e.g.:
 "HKLM:\SOFTWARE\7-Zip"

 .PARAMETER ExportPath
 Specifies path to .reg file to which registry key will be exported.

 .PARAMETER ImportPath
 Specifies path to .reg file from which registry key will be imported.

 .PARAMETER Credential
 Specifies credentials to access remote systems.

 .EXAMPLE
 C:\PS> .\Check_Backup_Restore_registry_key.ps1 -backup -RegKeypath 'HKLM:\SOFTWARE\7-Zip' -ExportPath 'D:\temp\reg1234.reg' -Credential $cred
 Script exports specified registry key to 'D:\temp\reg1234.reg' file.
#>

#Requires -Version 4.0
Param(
[ValidateNotNullOrEmpty()]
[ValidateScript({Test-NetConnection -ComputerName $_ -Port 5985 -InformationLevel Quiet})]
[string[]]$compnames,

[Parameter (Mandatory=$true,ParameterSetName='Backup')]
[switch]$backup,

[Parameter (Mandatory=$true,ParameterSetName='Restore')]
[switch]$restore,

[Parameter (Mandatory=$true,ParameterSetName='Check')]
[switch]$check,

[Parameter (Mandatory=$true,ParameterSetName='Clear')]
[switch]$clear,

[ValidateNotNullOrEmpty()]
[Parameter (Mandatory=$true,ParameterSetName='Backup')]
[Parameter (Mandatory=$true,ParameterSetName='Check')]
[Parameter (Mandatory=$true,ParameterSetName='Clear')]
[string]$RegKeypath,

[ValidateNotNullOrEmpty()]
[Parameter (Mandatory=$true,ParameterSetName='Backup')]
[string]$ExportPath,

[ValidateNotNullOrEmpty()]
[Parameter (Mandatory=$true,ParameterSetName='Restore')]
[string]$ImportPath,

[Parameter (Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[PSCredential]
[System.Management.Automation.Credential()]
$Credential
)

#Import function to import registry key from file
. .\Import-RegistryKey.ps1

#Import function to export registry key to file
. .\Export-RegistryKey.ps1

#Backup procedure
if ($backup -eq $true)
{
Invoke-Command -ComputerName $compnames -ScriptBlock {if ((Test-Path -Path $Using:ExportPath) -eq $true){Remove-Item -Path $Using:ExportPath -Force}} -Credential $Credential
Invoke-Command -ComputerName $compnames -ScriptBlock ${function:Export-RegistryKey} -ArgumentList $RegKeypath,$ExportPath -Credential $Credential
}

#Restore procedure
if ($restore -eq $true)
{
Invoke-Command -ComputerName $compnames -ScriptBlock ${function:Import-RegistryKey} -ArgumentList $ImportPath -Credential $Credential
}

#Query registry key
if ($check -eq $true)
{
    Invoke-Command -ComputerName $compnames -ScriptBlock {
        if ((Test-Path -Path $Using:RegKeypath) -eq $true){
        $subkeycontent=Get-ChildItem -Path $using:RegKeypath -Recurse
            if (!$subkeycontent) {
            Write-Verbose -Message "Looks like reg key $using:RegKeypath doesn't contain subkeys on host $env:COMPUTERNAME. Checking for reg entries..." -Verbose
            $entriescontent=Get-ItemProperty -Path $using:RegKeypath
                if (!$entriescontent) {
                Write-Verbose -Message "Looks like reg key $using:RegKeypath doesn't contain entries either on host $env:COMPUTERNAME." -Verbose
                }
                else {
                Write-Verbose -Message "Entries of reg key $using:RegKeypath on host $env:COMPUTERNAME are:" -Verbose
                $entriescontent
                }
            }
            else {
            Write-Verbose -Message "Subkey(s) of reg key $using:RegKeypath on host $env:COMPUTERNAME are:" -Verbose
            $subkeycontent
            }
        }
        else {
        Write-Verbose -Message "Reg key $using:RegKeypath doesn't exist on host $env:COMPUTERNAME. Please, check path to this registry key and run query again." -Verbose
        }
    } -Credential $Credential
}

#Clear registry key content
if ($clear -eq $true)
{
    Invoke-Command -ComputerName $compnames -ScriptBlock {
        if ((Test-Path -Path $Using:RegKeypath) -eq $true){
        $subkeycontent=Get-ChildItem -Path $using:RegKeypath -Recurse
            if (!$subkeycontent) {
            Write-Verbose -Message "Looks like reg key $using:RegKeypath doesn't contain subkeys on host $env:COMPUTERNAME. Checking for reg entries..." -Verbose
            $entriescontent=Get-ItemProperty -Path $using:RegKeypath
                if (!$entriescontent) {
                Write-Verbose -Message "Looks like reg key $using:RegKeypath doesn't contain entries either on host $env:COMPUTERNAME.`nNothing to clear." -Verbose
                }
                else {
                Write-Verbose -Message "Removing entries of reg key $using:RegKeypath on host $env:COMPUTERNAME" -Verbose
                Remove-ItemProperty -Path $using:RegKeypath -Name * -Force
                }
            }
            else {
            Write-Verbose -Message "Removing content of reg key $using:RegKeypath on host $env:COMPUTERNAME" -Verbose
            $allcontent=Join-Path -Path $using:RegKeypath -ChildPath "*"
            Remove-Item -Path $allcontent -Recurse -Force
            }
        }
        else {
        Write-Verbose -Message "Reg key $using:RegKeypath doesn't exist on host $env:COMPUTERNAME. Please, check path to this registry key and run query again." -Verbose
        }
    } -Credential $Credential
}