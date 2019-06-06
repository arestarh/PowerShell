function ConvertFrom-JsonToHashtable {
    <#
    .SYNOPSIS
    Converts a JSON-formatted string to hashtable

    .DESCRIPTION
    Converts a JSON-formatted string to hashtable

    .PARAMETER InputJson
    Specifies the JSON strings to convert to hashtable. Enter a variable that contains the string, or type a command or expression that gets the string.
    The InputObject parameter is required, but its value can be an empty string.
    When the input object is an empty string, ConvertFrom-JsonToHashtable does not generate any output. The InputObject value cannot be $null.

    .EXAMPLE
    C:\PS> ConvertFrom-JsonToHashtable -InputJson (Get-Content -Path "C:\workdir\test.json" -Raw)
    Function converts JSON string read from .json file to hashtable.
    #>

    [CmdletBinding()]
    param (
        [ValidateNotNull()]
        $InputJson = $(Throw "Parameter missing: -InputJson InputJson")
    )

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        Write-Warning -Message "Seems like you are using PowerShell version 6 or newer. You can use native inbuilt cmdlet 'ConvertFrom-Json' with parameter 'AsHashtable' to achieve the same goal instead of using this function."
    }

    try {
        if ([string]::IsNullOrWhiteSpace($InputJson) -eq $false) {
            # Converting JSON to Hashtable
            [Reflection.Assembly]::LoadWithPartialName("System.Web.Script.Serialization")
            $JSSerializer = [System.Web.Script.Serialization.JavaScriptSerializer]::new()
            $resulting_hashtable = $JSSerializer.Deserialize($InputJson,'Hashtable')
            return $resulting_hashtable
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSitem)
    }
}
