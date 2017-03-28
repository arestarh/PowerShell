 function Test-SslProtocol {
 <#
 .DESCRIPTION
   Outputs the SSL protocols that the client is able to successfully use to connect to a server.
 
 .NOTES
 
   Copyright 2014 Chris Duck
   http://blog.whatsupduck.net
 
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
 
     http://www.apache.org/licenses/LICENSE-2.0
 
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

   Be aware, that function does not check server certificate revocation list during authentication.
    
 .PARAMETER ComputerName
   The name of the remote computer to connect to.
 
 .PARAMETER Port
   The remote port to connect to. The default is 443.

 .PARAMETER MutualAuthentication
   Specifies whether mutual authentication is required.

 .PARAMETER ClientCertificate
   Specifies client certificate object in case mutual authentication is required.
 
 .EXAMPLE
  C:\PS> . .\Test-SslProtocols.ps1
  C:\PS> Test-SslProtocols -ComputerName "forums.asp.net"
   
   ComputerName      : forums.asp.net
   Port              : 443
   Ssl2              : False
   Ssl3              : False
   Tls               : True
   Tls11             : True
   Tls12             : True
   RemoteCertificate : [Subject]
                      CN=*.asp.net
                    
                    [Issuer]
                      CN=Microsoft IT SSL SHA2, OU=Microsoft IT, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
                    
                    [Serial Number]
                      5A0006EA0B4722D53C67FE1E8800010006EA0B
                    
                    [Not Before]
                      02/03/2017 21:08:29
                    
                    [Not After]
                      02/04/2018 22:08:29
                    
                    [Thumbprint]
                      3CE5E0D96FAB6B949D8675E9638DCDE50B86E818
 #>
   [CmdletBinding(DefaultParameterSetName='ServerAuthentication',SupportsShouldProcess=$true)]
   Param(
     [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,ParameterSetName='ServerAuthentication')]
     [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,ParameterSetName='MutualAuthentication')]
     [ValidateNotNullOrEmpty()]
     [string]$ComputerName,
     
     [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='ServerAuthentication')]
     [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='MutualAuthentication')]
     [ValidateNotNullOrEmpty()]
     [int]$Port = 443,

     [Parameter(Mandatory=$true,ParameterSetName='MutualAuthentication')]
     [switch]$MutualAuthentication,

     [Parameter(Mandatory=$true,ParameterSetName='MutualAuthentication')]
     [System.Security.Cryptography.X509Certificates.X509Certificate2]$ClientCertificate
   )

   begin {
     #SslProtocols Enumeration (Enumeration of System.Security.Authentication Namespace)
     $ProtocolNames = [System.Security.Authentication.SslProtocols] | Get-Member -Static -MemberType Property | Where-Object -FilterScript {$_.Name -notin @("Default","None")} | Select-Object -ExpandProperty Name
   }
   process {
     #Protocol Status object
     $ProtocolStatus = New-Object -TypeName PSObject
     Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name ComputerName -Value $ComputerName
     Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name Port -Value $Port
     
     #Certificate variable for certificate object
     $servercert=$null

     #Creating empty certificate collection object and adding client certificate object to created collection (if mutual authentification is required)
     if ($MutualAuthentication -eq $true)
     {
     $certcoll=New-Object -TypeName System.Security.Cryptography.X509Certificates.X509CertificateCollection
     $certcoll.Add($ClientCertificate)
     }

     $ProtocolNames | ForEach-Object -Process {
       $ProtocolName = $_
       Write-Verbose -Message "Start checking support of remote host $ComputerName to use security protocol $ProtocolName." -Verbose

       #Create socket using constructor Socket(SocketType, ProtocolType) of Socket Class
       $Socket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.SocketType]::Stream, [System.Net.Sockets.ProtocolType]::Tcp)

       #Using Connect method of Socket Class to establish a connection to a remote host.
       Write-Verbose -Message "Creating socket and connecting to remote host $ComputerName on port $Port." -Verbose
       try {
       $Socket.Connect($ComputerName, $Port)
       }
       catch [System.Net.Sockets.SocketException]
       {
       Write-Verbose -Message "Failed to create socket connection for host $ComputerName on port $Port`:" -Verbose
       Write-Verbose -Message "$_" -Verbose
       Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name $ProtocolName -Value 'Failed'
       Return
       }

       #Using different classes of System.Net.Sockets Namespace, System.Net.Security Namespace to control secure communications between hosts
       try {
         Write-Verbose -Message "Creating network, ssl streams" -Verbose
         $NetStream = New-Object System.Net.Sockets.NetworkStream($Socket, $true)
         $SslStream = New-Object System.Net.Security.SslStream($NetStream, $true)
             if ($MutualAuthentication -eq $true -and $ProtocolName -ne 'Ssl2')
             {
             Write-Verbose -Message "Starting authentification process using $ProtocolName protocol. Mutual authentification is used." -Verbose
             $SslStream.AuthenticateAsClient($ComputerName,  $certcoll, $ProtocolName, $false)
             }
             else {
             Write-Verbose -Message "Starting authentification process using $ProtocolName protocol." -Verbose
             $SslStream.AuthenticateAsClient($ComputerName,  $null, $ProtocolName, $false)
             }
         $RemoteCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]$SslStream.RemoteCertificate
         if (!$servercert)
         {
         $servercert=$RemoteCertificate
         }
         Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name $ProtocolName -Value $true
         Write-Verbose -Message "Successfully authenticated using $ProtocolName protocol." -Verbose
       } catch  {
         Write-Verbose -Message "Failed to authenticate using $ProtocolName protocol.`n$_" -Verbose
             if ($_.Exception.InnerException -match "The remote certificate is invalid according to the validation procedure.")
             {
             Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name $ProtocolName -Value 'Failed'
             }
             else 
             {
             Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name $ProtocolName -Value $false
             }
       } finally {
         $SslStream.Close()
       }
     }
     if ($servercert)
     {
     Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name RemoteCertificate -Value $servercert
     $ProtocolStatus
     }
     else {
     $ProtocolStatus
     }
   }
 }
