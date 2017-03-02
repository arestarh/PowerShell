Function Restore-Registry {
<#
 .SYNOPSIS
 Imports registry key from .reg file

 .DESCRIPTION
 Imports registry key from .reg file
 
 .NOTES
 Wrapper of reg.exe IMPORT capabilities

 .PARAMETER regfilepath
 Specifies path to .reg file from which registry key will be imported.

 .EXAMPLE
 C:\PS> . .\Restore-Registry.ps1
 C:\PS> Restore-Registry -regfilepath 'D:\temp\reg1234.reg'
 Script imports specified registry key from 'D:\temp\reg1234.reg' file.
#>

Param(
[ValidateNotNullOrEmpty()]
[ValidatePattern('\.reg$')]
[ValidateScript({Test-Path -Path $_})]
[string]$regfilepath
)

#Path to reg util
$regutilpath="c:\windows\system32\reg.exe"

#Intialize basic object
$hostname=Get-Item -Path Env:\COMPUTERNAME|Select-Object -ExpandProperty Value
$obj=New-Object -TypeName PSObject
Add-Member -InputObject $obj -MemberType NoteProperty -Name Hostname -Value $hostname

#Import reg key
$err=$null
$command="$regutilpath IMPORT $regfilepath"
Invoke-Expression -command $command -ErrorAction SilentlyContinue -ErrorVariable +err|Out-Null
if ($LASTEXITCODE -eq '0')
{
Write-Verbose -Message "Reg key from file $regfilepath was imported successfully." -Verbose
Add-Member -InputObject $obj -MemberType NoteProperty -Name Reg_import_exit_code -Value $LASTEXITCODE
}
else {
Write-Error -Message "Error occured during importing Reg key from file $regfilepath`:`n$err." -Verbose
Add-Member -InputObject $obj -MemberType NoteProperty -Name Reg_import_exit_code -Value $LASTEXITCODE
}
$obj
}
