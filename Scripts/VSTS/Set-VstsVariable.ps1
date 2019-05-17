function Set-VstsVariable {
    param(
        [string]$variable_name,
        [string]$value,
        [switch]$is_multijob_variable,
        [switch]$is_secret_variable
    )

    if ($is_multijob_variable -eq $true) {
        if ($is_secret_variable -eq $true) {
            Write-Host -Object ("##vso[task.setvariable variable=$variable_name;isOutput=true;issecret=true]$value")
        }
        else {
            Write-Host -Object ("##vso[task.setvariable variable=$variable_name;isOutput=true]$value")
        }
    }
    else {
        if ($is_secret_variable -eq $true) {
            Write-Host -Object ("##vso[task.setvariable variable=$variable_name;issecret=true]$value")
        }
        else {
            Write-Host -Object ("##vso[task.setvariable variable=$variable_name]$value")
        }
    }
}
