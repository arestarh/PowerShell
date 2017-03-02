function Convert-IISLogsToObject {
<#
    .Synopsis
        Converts plain text IIS logs into a PS Object
    .DESCRIPTION
        Converts plain text IIS logs into a PS Object
    .NOTES
        More info about logging in IIS you can find there:
        https://www.iis.net/learn/manage/provisioning-and-managing-iis/configure-logging-in-iis
    .PARAMETER path
        Specifies path to IIS log files. 
    .PARAMETER logformat
        Specifies IIS log file format. The acceptable values for this parameter are: 
        "W3C", "IIS","NCSA"
    .EXAMPLE
        Get-ChildItem '<path to logs>\*.log' | Convert-IISLogsToObject -logformat IIS| Sort-Object c-ip -Unique
    .EXAMPLE
        Convert-IISLogsToObject -path (Get-ChildItem '<path to logs>\*log') -logformat W3C| Where-Object { $_.'cs-username' -eq '<userName>' } | Sort-Object c-ip -Unique
    .NOTES
        General notes
    .AUTHOR
        Ben Taylor - 09/07/2016
    .LINK
        http://bentaylor.work/2016/09/parsing-iis-logs-to-powershell-objects/
#>

    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateScript({ Test-Path -Path $_ })]
        [string[]]$path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
	    [ValidateSet("NCSA", "W3C", "IIS")]
        [string]$logformat
    )

    Process {

    <#
    Define headers for IIS, NCSA log formats
    Headers are fixed for IIS and NCSA log formats
    #>
    #IIS
    ##Client IP address, User name, Date, Time, Service and instance, Server name, Server IP address, Time taken, Client bytes sent, Server bytes sent, Service status code, Windows status code, Request type, Target of operation, Parameters
    $IISheaders='c-ip', 'username', 'date', 'time', 'service', 'server', 's-ip', 'timetaken', 'c-bsent', 's-bsent', 'service-sc', 'windows-sc', 'request-type', 'target', 'parameters'
    #NCSA
    ##Remote host address, Remote log name (This value is always a hyphen), user name, Date, time, Greenwich mean time (GMT) offset, Request and protocol version, Service status code, Bytes sent
    $NCSAheaders='remote-hostaddr', 'remote-logname', 'username', 'date', 'time', 'GMToffset', 'request-method', 'request', 'protocol-version', 'service-sc', 'bytes-sent'

        switch ($logformat) { 
            "W3C"
                {
                  forEach($filePath in $path) {
                      $W3Cheaders = (Get-Content -Path $filePath -TotalCount 4 | Select-Object -First 1 -Skip 3) -replace '#Fields: ' -split ' '
                      Get-Content -Path $filePath | Select-String -Pattern '^#' -NotMatch | ConvertFrom-Csv -Delimiter ' ' -Header $W3Cheaders
                  }
                } 
            "IIS"
                {
                  forEach($filePath in $path) {
                      Get-Content -Path $filePath | ConvertFrom-Csv -Delimiter ',' -Header $IISheaders
                  }
                }
            "NCSA"
                {
                  forEach($filePath in $path) {
                      #Character set (in each log string) that represents Date, time and Greenwich mean time (GMT) offset, are modified to fit in defined Headers, e.g. [03/Feb/2017:09:44:14 +0200] replaced by 03/Feb/2017 09:44:14 +0200
                      #Character set (in each log string) that represents Request and protocol version, are modified to fit in defined Headers, e.g. "GET /2016-08-22-php7.html HTTP/1.1" replaced by GET /2016-08-22-php7.html HTTP/1.1
                      Get-Content -Path $filePath | ForEach-Object -Process {($_ -replace '\[(.*):(\d{2}:\d{2}:\d{2})\s([-+]\d+)\]','$1 $2 $3') -replace '\"(.*)\"','$1'}| ConvertFrom-Csv -Delimiter ' ' -Header $NCSAheaders
                  }
                } 
        }
    }
}
