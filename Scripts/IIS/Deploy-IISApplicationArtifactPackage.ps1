<#
.SYNOPSIS
Deploys application artifact package to IIS web site or application.
#>

[CmdletBinding()]
#Requires -RunAsAdministrator
param (
    [ValidatePattern('\.zip$')]
    [Parameter (Mandatory=$true,HelpMessage="Provide full path to application artifact package (in form of .zip archive)")]
    [string]$PackagePath,

    [ValidateNotNullOrEmpty()]
    [Parameter (Mandatory=$true,HelpMessage="Provide the IIS web site name where to deploy application artifact package")]
    [string]$SiteName,

    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,

    [switch]$EmptyApplicationFolder
)

try {
    # Ensure WebAdministration Powershell module is installed
    if (!(Get-Module -Name WebAdministration -ListAvailable -ErrorAction Stop)) {
        Write-Warning -Message "Deploy-IISApplicationArtifactPackage.ps1 script requires WebAdministration Powershell module to be installed. Further script execution will be skipped."
        Return
    }
    Import-Module -Name WebAdministration -ErrorAction Stop

    # Function to expand archive for Powershell versions lower than 5.x
    function Expand-ZIPFile {
        <#
        .SYNOPSIS
        Expands archive content to folder using Folder.CopyHere method.

        .NOTES
        Folder.CopyHere flags used:
        (4) Do not display a progress dialog box.
        (16) Respond with "Yes to All" for any dialog box that is displayed.
        (512) Do not confirm the creation of a new directory if the operation requires one to be created.
        (1024) Do not display a user interface if an error occurs.

        .LINK
        https://docs.microsoft.com/en-us/windows/desktop/shell/folder-copyhere
        https://social.technet.microsoft.com/Forums/en-US/8e5fb755-c3e2-4f8d-91e4-1a12913262d9/powershell-unzip-with-shellapplication-not-working-when-launched-from-windows-service?forum=winserverpowershell
        #>

        [CmdletBinding()]
        param (
            [string]$file,
            [string]$destination
        )

        try {
            $shell = New-Object -ComObject shell.application
            $zip = $shell.NameSpace($file)
            foreach($item in $zip.items()) {
                $shell.Namespace($destination).CopyHere($item,1556)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }

    # Expand environment variables in path, if any
    if ($PackagePath -match "\%") {
        $PackagePath = [Environment]::ExpandEnvironmentVariables($PackagePath)
    }

    # Check if path to artifact exists
    if((Test-Path -Path $PackagePath -ErrorAction Stop) -eq $false) {
        Write-Warning -Message "Path to application artifact package does not exist. Please, provide path to .zip file of application artifact package and run script again."
        Return
    }

    # Check if path to artifact points to File
    if((Test-Path -Path $PackagePath -PathType Leaf -ErrorAction Stop) -eq $true) {
        # Convert path to absolute form if path was provided in relative format
        $PackagePath = (Resolve-Path -Path $PackagePath -ErrorAction Stop).Path

        if ($ApplicationName) {
            $app_item = Get-WebApplication -Site $SiteName -Name $ApplicationName -ErrorAction Stop
            $app_item_type = "application"
            $app_item_name = "$SiteName\$ApplicationName"
        }
        else {
            $app_item = Get-Website -Name $SiteName -ErrorAction Stop
            $app_item_type = "site"
            $app_item_name = "$SiteName"
        }

        if ($app_item) {
            # Check application pool state and stop it if needed
            if ((Get-WebAppPoolState -Name $app_item.applicationPool -ErrorAction Stop).Value -eq "Started" ) {
                Write-Verbose -Message "Stopping application pool '$($app_item.applicationPool)' of $app_item_type '$app_item_name'"
                Stop-WebAppPool -Name $app_item.applicationPool -ErrorAction Stop
            }

            # Expand environment variables in path, if any
            if ($app_item.PhysicalPath -match "\%") {
                $app_item_physicalpath = [Environment]::ExpandEnvironmentVariables($app_item.PhysicalPath)
            }
            $app_item_physicalpath = $app_item.PhysicalPath

            # Empty application folder if needed
            if (Get-ChildItem -Path $app_item_physicalpath -Recurse -ErrorAction Stop) {
                if ($EmptyApplicationFolder -eq $true) {
                    Write-Verbose -Message "Removing content of physical folder '$app_item_physicalpath' for $app_item_type '$app_item_name'"
                    Remove-Item -Path "$app_item_physicalpath\*" -Recurse -Force -ErrorAction Stop
                }
            }

            # Choose expand method based on Powershell version
            if ($PSVersionTable.PSVersion.Major -lt 5) {
                Write-Verbose -Message "Extracting artifact package '$PackagePath' for $app_item_type '$app_item_name' to folder '$app_item_physicalpath'"
                Expand-ZIPFile -file $PackagePath -destination $app_item_physicalpath
            }
            else {
                Write-Verbose -Message "Extracting artifact package '$PackagePath' for $app_item_type '$app_item_name' to folder '$app_item_physicalpath'"
                Expand-Archive -Path $PackagePath -DestinationPath $app_item_physicalpath -ErrorAction Stop -Force
            }

            # Check application pool state and start it if needed
            if ((Get-WebAppPoolState -Name $app_item.applicationPool -ErrorAction Stop).Value -eq "Stopped" ) {
                Write-Verbose -Message "Starting application pool '$($app_item.applicationPool)' of $app_item_type '$app_item_name'"
                Start-WebAppPool -Name $app_item.applicationPool -ErrorAction Stop
            }
        }
        else {
            Write-Warning -Message "Specified $app_item_type '$app_item_name' does not exist. Please, provide name of existing $app_item_type and run script again."
            Return
        }
    }
    else {
        Write-Warning -Message "Path to application artifact package points to folder rather than .zip archive. Please, provide path to .zip file of application artifact package and run script again."
        Return
    }
}
catch {
    $PSCmdlet.ThrowTerminatingError($PSitem)
}
