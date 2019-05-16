function Expand-ZIPFileV2 {
    <#
    .SYNOPSIS
    Expands archive content to folder using ZipFile.ExtractToDirectory Method.

    .NOTES
    Applies to .NET Framework grater than version 4.5.

    .LINK
    https://docs.microsoft.com/en-us/dotnet/api/system.io.compression.zipfile.extracttodirectory?view=netframework-4.8
    https://www.saotn.org/unzip-file-powershell/
    #>

    [CmdletBinding()]
    param (
        [string]$ziparchive,
        [string]$extractpath
    )

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        [System.IO.Compression.ZipFile]::ExtractToDirectory( $ziparchive, $extractpath )
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSitem)
    }
}