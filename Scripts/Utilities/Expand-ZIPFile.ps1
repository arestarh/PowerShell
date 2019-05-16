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