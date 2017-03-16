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
 
 .PARAMETER ComputerName
   The name of the remote computer to connect to.
 
 .PARAMETER Port
   The remote port to connect to. The default is 443.
 
 .EXAMPLE
   Test-SslProtocols -ComputerName "www.google.com"
   
   ComputerName       : www.google.com
   Port               : 443
   Ssl2               : False
   Ssl3               : True
   Tls                : True
   Tls11              : True
   Tls12              : True
   RemoteCertificate  : CertificateObject
 #>

   Param(
     [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
     $ComputerName,
     
     [Parameter(ValueFromPipelineByPropertyName=$true)]
     [int]$Port = 443
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
     $cert=$null

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
         Write-Verbose -Message "Creating network, ssl stream and authenticate using $ProtocolName protocol." -Verbose
         $NetStream = New-Object System.Net.Sockets.NetworkStream($Socket, $true)
         $SslStream = New-Object System.Net.Security.SslStream($NetStream, $true)
         $SslStream.AuthenticateAsClient($ComputerName,  $null, $ProtocolName, $false)
         $RemoteCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]$SslStream.RemoteCertificate
         if (!$cert)
         {
         $cert=$RemoteCertificate
         }
         Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name $ProtocolName -Value $true
         Write-Verbose -Message "Successfully authenticated using $ProtocolName protocol." -Verbose
       } catch  {
         Write-Verbose -Message "Failed to authenticate using $ProtocolName protocol.`n$_" -Verbose
         Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name $ProtocolName -Value $false
       } finally {
         $SslStream.Close()
       }
     }
     if ($cert)
     {
     Add-Member -InputObject $ProtocolStatus -MemberType NoteProperty -Name RemoteCertificate -Value $cert
     $ProtocolStatus
     }
     else {
     $ProtocolStatus
     }
   }
 }
