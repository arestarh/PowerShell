function New-RandomPassword {
    <#
    .SYNOPSIS
    Generates a random password of the specified length

    .DESCRIPTION
    Generates a random password of the specified length

    .PARAMETER Length
    Specifies the number of characters in the generated password.

    .PARAMETER NumberOfNonAlphanumericCharacters
    Specifies the minimum number of non-alphanumeric characters (such as @, #, !, %, &, and so on) in the generated password.

    .PARAMETER AsPlainText
    Specifies whether generated password should be in plain text or converted to secure string.

    .EXAMPLE
    C:\PS> New-RandomPassword -Length 30 -NumberOfNonAlphanumericCharacters 7
    Function generates password 30 characters long with minimun 7 non-alphanumeric characters in it and outputs it as secure string.
    #>

    [CmdletBinding()]
    param (
        [ValidateRange(1,128)]
        [int]$Length = $(Throw "Parameter missing: -Length Length"),

        [ValidateScript({$_ -gt 0})]
        [int]$NumberOfNonAlphanumericCharacters = $(Throw "Parameter missing: -NumberOfNonAlphanumericCharacters NumberOfNonAlphanumericCharacters"),

        [switch]$AsPlainText
    )

    if ($NumberOfNonAlphanumericCharacters -gt $Length) {
        Write-Warning -Message "Number of non-alphanumeric characters must be less than overall password length. Please, specify correct number of non-alphanumeric characters and execute script again."
        Return
    }

    try {
        if ($AsPlainText -eq $false) {
            $PasswordValue = [System.Web.Security.Membership]::GeneratePassword($Length,$NumberOfNonAlphanumericCharacters) | ConvertTo-SecureString -AsPlainText -Force
        }
        else {
            $PasswordValue = [System.Web.Security.Membership]::GeneratePassword($Length,$NumberOfNonAlphanumericCharacters)
        }
        return $PasswordValue
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSitem)
    }
}
