Function Compress-File
{
 <#
 .SYNOPSIS
 Compress files into .zip archives.

 .DESCRIPTION
 Compress files into .zip archives.
 Function uses ideas from Jeff Hicks function:
 https://www.petri.com/create-zip-archives-with-powershell-and-the-shell-application-com-object

 .PARAMETER soursepath
 Specifies the path to soursepath file\directory where files that will be compressed are located.
 Parameter is mandatory, so if you miss it, script will not run and throw an exception.

  .PARAMETER destpath
 Specifies the path to destination .zip file.
 Parameter is mandatory, so if you miss to provide ".zip" extension, script will not run and throw an exception.

 .PARAMETER force
 Specifies whether or not to remove .zip archive with the same name as provided in destpath parameter, in case archive already exists. 

 .EXAMPLE
 C:\PS> . .\Compress-File.ps1
 C:\PS> Compress-File -soursepath "D:\Logs" -destpath "D:\Logs\archive.zip"
 Function compresses all files from "D:\Logs" directory and place them into "D:\Logs\archive.zip" archive.

 .EXAMPLE
 C:\PS> . .\Compress-File.ps1
 C:\PS> Compress-File -soursepath "D:\Logs\file.txt" -destpath "D:\Logs\archive_new.zip" -force
 Function compresses file "D:\Logs\file.txt" and place it into "D:\Logs\archive_new.zip" archive. In case "D:\Logs\archive_new.zip" archive already exists, it will be removed.
 #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
	(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$soursepath = $(Throw "Please, provide a full path to sourse file"),

        [ValidateNotNullOrEmpty()]
        [ValidatePattern('\.zip$')]
        [string]$destpath = $(Throw "Please, provide a full path to destination .zip file"),

   		[switch]$force
	)

  #Convert sourse path to absolute form if path was provided in relative format
  $soursepath=(Resolve-Path -Path $soursepath).Path

  #Remove existing .zip file, if $Force parameter was provided
  if ($force -eq $true -and (Test-Path -Path $destpath) -eq $true)
    {
      #Check for exception situation when Sourse and Distanation path are the same (and either point to same .zip file or sourse is Folder and named like "Folder_Name.zip")
      if ($soursepath -eq (Resolve-Path -Path $destpath).Path)
      {
      Write-Error -Message "Be aware, that you've specified the same path for sourse and destination and Force parameter is used:`n$destpath.`nTo avoid errors, script execution was aborted.`nPlease, use another path for destination .zip file." -Verbose
      Return
      }
      else {
            try{Remove-Item -Path $destpath -Force -ErrorAction Stop}
            catch
                {
                Write-Error "Error has occurred while forcing file deletion: $destpath" -Verbose
                Write-Verbose $_ -Verbose
                Return
                }
           }
    }
    
  #Show error message when destination .zip archive already exists and Force parameter was not provided
  if ($force -eq $false -and (Test-Path -Path $destpath) -eq $true)
      {
      Write-Error -Message "Archive File $destpath already exists: please, delete file or use Force parameter" -Verbose
      Return
      }

  #Set destination path
              try
                {
		        #We are adding the file header and creating a 0 byte .zip file.
                Set-Content -Path $destpath -Value ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18)) -ErrorAction Stop

                #Check if just created 0 byte .zip file has ReadOnly attribute set
                $destpathitem=Get-Item -Path $destpath -ErrorAction Stop
                if ($destpathitem.IsReadOnly -eq $true) {$destpathitem.IsReadOnly = $false}
                }
            catch
                {
                Write-Error -Message "Error has occurred while setting destination path" -Verbose
                Write-Verbose -Message $_ -Verbose
                Return
                }
  
  #Convert destination paths to absolute form if path was provided in relative format
  $destpath=(Resolve-Path -Path $destpath).Path
  
  #We are starting zipping the file.
            try
                {
		        $ZipFile = New-Object -ComObject Shell.Application -ErrorAction Stop
                $ZipFile=$ZipFile.NameSpace($destpath)
                }
            catch
                {
                Write-Error -Message "Error has occurred while creating Shell COM object and invoking Namespace method (creating and returning a Folder object): $soursepath" -Verbose
                Write-Verbose -Message $_ -Verbose
                Return
                }
            try
                {
                $soursepathitem=Get-Item -Path $soursepath -ErrorAction Stop
                $ZipFile.CopyHere($soursepath)
                while(!$ZipFile.Items().Item($soursepathitem.Name))
                   {
                      Start-Sleep -Seconds 1
                   }
                }
            catch
                {
                 Write-Error -Message "Error has occurred while invoking CopyHere method (copying an item or items to a folder): $soursepath" -Verbose
                 Write-Verbose -Message $_ -Verbose
                Return
                }
}
