Function Export-RegistryKey {
<#
 .SYNOPSIS
 Exports registry key to .reg file

 .DESCRIPTION
 Exports registry key to .reg file

 .PARAMETER keypath
 Specifies path to registry key in Powershell PSDrive format. e.g.:
 "HKLM:\SOFTWARE\7-Zip"

  .PARAMETER ExportPath
 Specifies path to .reg file to which registry key will be exported.

   .PARAMETER force
 Specifies whether to overwrite existing .reg file or not.

 .EXAMPLE
 C:\PS> . .\Backup-Registry.ps1
 C:\PS> Backup-Registry -keypath "HKLM:\SOFTWARE\7-Zip" -ExportPath 'D:\temp\reg1234.reg' -force
 Script exports specified registry key to 'D:\temp\reg1234.reg' file and overwrites existing file if it already exists.
#>

Param(
[ValidateNotNullOrEmpty()]
[Parameter(Mandatory=$True,HelpMessage="Enter a registry path using the PSDrive format.")]
[ValidateScript({Test-Path -Path $_})]
[string]$keypath,

[ValidateNotNullOrEmpty()]
[ValidatePattern('\.reg$')]
[string]$ExportPath,

[switch]$force
)

#Path to reg util
$regutilpath="c:\windows\system32\reg.exe"

#Change path to key from PSPath to format that reg.exe can handle
$keypathreg=$keypath -replace ":",""

#Intialize basic object
$obj=New-Object -TypeName PSObject
Add-Member -InputObject $obj -MemberType NoteProperty -Name Hostname -Value $env:COMPUTERNAME

#Export reg key with overwriting existing key file
if ($force -eq $True -and (Test-Path -Path $ExportPath) -eq $True)
{
    $err=$null
    $command="$regutilpath EXPORT $keypathreg $ExportPath /y"
    Invoke-Expression -command $command -ErrorAction SilentlyContinue -ErrorVariable +err|Out-Null
    if ($LASTEXITCODE -eq '0')
    {
    Write-Verbose -Message "Reg key $keypathreg was exported successfully to file $ExportPath." -Verbose
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Reg_export_exit_code -Value $LASTEXITCODE
    }
    else {
    Write-Error -Message "Error occured during exporting key $keypathreg to file $ExportPath`:`n$err." -Verbose
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Reg_export_exit_code -Value $LASTEXITCODE
    }
    $obj
Return
}

#Warning if Reg File already exists and -force parameter was not specified
if ($force -eq $false -and (Test-Path -Path $ExportPath) -eq $True)
{
Write-Error -Message "Reg File $ExportPath already exists: please, delete file or use Force parameter" -Verbose
Return
}

#Export reg key without overwriting existing key file
    $err=$null
    $command="$regutilpath EXPORT $keypathreg $ExportPath"
    Invoke-Expression -command $command -ErrorAction SilentlyContinue -ErrorVariable +err|Out-Null
    if ($LASTEXITCODE -eq '0')
    {
    Write-Verbose -Message "Reg key $keypathreg was exported successfully to file $ExportPath." -Verbose
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Reg_export_exit_code -Value $LASTEXITCODE
    }
    else {
    Write-Error -Message "Error occured during exporting key $keypathreg to file $ExportPath`:`n$err" -Verbose
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Reg_export_exit_code -Value $LASTEXITCODE
    }
    $obj
}
