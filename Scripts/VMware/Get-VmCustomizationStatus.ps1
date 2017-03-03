Function Get-VmCustomizationStatus
{
<#
.SYNOPSIS 
Waits customization process for list of virtual machines to complete.

.DESCRIPTION 
Waits customization process for list of virtual machines to complete. 
The function returns status - if customization process ends for all virtual machines or if the specified timeout elapses. 
The function returns PSObject for each specified VM. 
The output object has VM and CustomizationStatus properties.

.NOTES
The function is based on several vCenter events:
* VmStarting event – this event is posted on power on operation
* CustomizationStartedEvent event – this event is posted for VM when customiztion has started
* CustomizationSucceeded event – this event is posted for VM when customization has successfully completed
* CustomizationFailed – this event is posted for VM when customization has failed

Possible CustomizationStatus values are:
* "VmNotStarted" – if it was not found VmStarting event for specific VM.
* "CustomizationNotStarted" – if it was not found CustomizationStarterdEvent for specific VM. 
* "CustomizationStarted" – CustomizationStartedEvent was found, but Succeeded or Failed events were not found.
* "CustomizationSucceeded" – CustomizationSucceeded event was found for this VM.
* "CustomizationFailed" – CustomizationFailed event was found for this VM.

Several function's features:
* It doesn’t accept pipeline input, because it checks the customization status for multiple virtual machines simultaneously. This won’t be possible if the process block script execution for each object passed by the pipeline.
* It also shows how to work with specific type of events.
* Its search queries for VIEvents are optimized by specifying specific entity and Start time filters.

.PARAMETER vmList
 Specifies the list of virtual machine's objects which should be monitored for the completion of a customization process.
 For each VM, function will look for the last VmStarting event, because the customization process starts after the VM has been powered on.
 As being said, we need to power on VM(s) to trigger customization process and pass list of VM(s) objects to funtion.

.PARAMETER timeoutSeconds
 Specifies timeout in seconds that the function should wait for the customization to end.

.INPUTS
None. You cannot pipe objects to Get-VmCustomizationStatus.

.OUTPUTS
System.Management.Automation.PSCustomObject. Get-VmCustomizationStatus returns list of PSObjects where each object holds a passed VM and its customization status – successful, failed, started, etc.

.LINK
Author - Vitali Baruh:
https://blogs.vmware.com/PowerCLI/2012/08/waiting-for-os-customization-to-complete.html

.EXAMPLE
C:\PS> . .\Get-VmCustomizationStatus.ps1
C:\PS> $vm = 1..10 | foreach { New-VM -Template WindowsXPTemplate -OSCustomizationSpec WindowsXPCustomizaionSpec -Name "winxp-$_" }
C:\PS> $vm = $vm | Start-VM
C:\PS> Get-VmCustomizationStatus -vmList $vm -timeoutSeconds 600
#> 

   [CmdletBinding()] 
   Param
   ( 
   # VMs to monitor for OS customization completion 
   [Parameter(Mandatory=$true)] 
   [ValidateNotNullOrEmpty()] 
   [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]] $vmList, 
   
   # timeout in seconds to wait 
   [int] $timeoutSeconds = 600 
   )

# constants for status 
      $STATUS_VM_NOT_STARTED = "VmNotStarted" 
      $STATUS_CUSTOMIZATION_NOT_STARTED = "CustomizationNotStarted" 
      $STATUS_STARTED = "CustomizationStarted" 
      $STATUS_SUCCEEDED = "CustomizationSucceeded" 
      $STATUS_FAILED = "CustomizationFailed" 
      
      $STATUS_NOT_COMPLETED_LIST = @( $STATUS_CUSTOMIZATION_NOT_STARTED, $STATUS_STARTED ) 
      
# constants for event types      
      $EVENT_TYPE_CUSTOMIZATION_STARTED = "VMware.Vim.CustomizationStartedEvent" 
      $EVENT_TYPE_CUSTOMIZATION_SUCCEEDED = "VMware.Vim.CustomizationSucceeded" 
      $EVENT_TYPE_CUSTOMIZATION_FAILED = "VMware.Vim.CustomizationFailed" 
      $EVENT_TYPE_VM_START = "VMware.Vim.VmStartingEvent"

# seconds to sleep before next loop iteration 
      $WAIT_INTERVAL_SECONDS = 15
    
   # the moment in which the script has started 
   # the maximum time to wait is measured from this moment 
   $startTime = Get-Date 
   
   # we will check for "start vm" events 5 minutes before current moment 
   $startTimeEventFilter = $startTime.AddMinutes(-5) 
   
   # initializing list of helper objects 
   # each object holds VM, customization status and the last VmStarting event 
   $vmDescriptors = @()#Create empty array 
   foreach($vm in $vmList) { 
      Write-Verbose -Message "Start monitoring customization process for VM $vm" -Verbose
      $obj = New-Object -TypeName PSObject 
      Add-Member -InputObject $obj -MemberType NoteProperty -Name VM -Value $vm
      # getting all events for the $vm, 
      #  filter them by type, 
      #  sort them by CreatedTime, 
      #  get the last one
      $StartVMEventValue=Get-VIEvent -Entity $vm -Start $startTimeEventFilter | Where-Object -FilterScript { $_.GetType().FullName -eq $EVENT_TYPE_VM_START } | Sort-Object CreatedTime | Select-Object -Last 1
      Add-Member -InputObject $obj -MemberType NoteProperty -Name StartVMEvent -Value $StartVMEventValue
         
      if (-not $obj.StartVMEvent) {
         Add-Member -InputObject $obj -MemberType NoteProperty -Name CustomizationStatus -Value $STATUS_VM_NOT_STARTED
      } else {
         Add-Member -InputObject $obj -MemberType NoteProperty -Name CustomizationStatus -Value $STATUS_CUSTOMIZATION_NOT_STARTED
      } 
      
      $vmDescriptors+=$obj
   }         
   
   # declaring script block which will evaulate whether 
   # to continue waiting for customization status update 
   $shouldContinue = { 
      # is there more virtual machines to wait for customization status update 
      # we should wait for VMs with status $STATUS_STARTED or $STATUS_CUSTOMIZATION_NOT_STARTED 
      $notCompletedVms = $vmDescriptors | Where-Object -FilterScript { $STATUS_NOT_COMPLETED_LIST -contains $_.CustomizationStatus }

      # evaulating the time that has elapsed since the script is running 
      $currentTime = Get-Date 
      $timeElapsed = $currentTime – $startTime 
      
      $timoutNotElapsed = ($timeElapsed.TotalSeconds -lt $timeoutSeconds) 
      
      # returns $true if there are more virtual machines to monitor 
      # and the timeout is not elapsed 
      $notCompletedVms -and $timoutNotElapsed
   } 
      
   while (& $shouldContinue) { 
      foreach ($vmItem in $vmDescriptors) { 
         $vmName = $vmItem.VM.Name 
         switch ($vmItem.CustomizationStatus) { 
            $STATUS_CUSTOMIZATION_NOT_STARTED { 
               # we should check for customization started event 
               $vmEvents = Get-VIEvent -Entity $vmItem.VM -Start $vmItem.StartVMEvent.CreatedTime 
               $startEvent = $vmEvents | Where-Object -FilterScript { $_.GetType().FullName -eq $EVENT_TYPE_CUSTOMIZATION_STARTED } 
               if ($startEvent) { 
                  Add-Member -InputObject $vmItem -MemberType NoteProperty -Name CustomizationStatus -Value $STATUS_STARTED -Force
                  Write-Verbose -Message "Customization for VM $vmName has started" -Verbose
               } 
               break; 
            } 
            $STATUS_STARTED { 
               # we should check for customization succeeded or failed event 
               $vmEvents = Get-VIEvent -Entity $vmItem.VM -Start $vmItem.StartVMEvent.CreatedTime 
               $succeedEvent = $vmEvents | Where-Object -FilterScript { $_.GetType().FullName -eq $EVENT_TYPE_CUSTOMIZATION_SUCCEEDED } 
               $failedEvent = $vmEvents | Where-Object -FilterScript { $_.GetType().FullName -eq $EVENT_TYPE_CUSTOMIZATION_FAILED } 
               if ($succeedEvent) { 
                  Add-Member -InputObject $vmItem -MemberType NoteProperty -Name CustomizationStatus -Value $STATUS_SUCCEEDED -Force
                  Write-Verbose -Message "Customization for VM $vmName has successfully completed" -Verbose
               } 
               if ($failedEvent) { 
                  Add-Member -InputObject $vmItem -MemberType NoteProperty -Name CustomizationStatus -Value $STATUS_FAILED -Force
                  Write-Verbose -Message "Customization for VM $vmName has failed" -Verbose
               } 
               break; 
            } 
            default { 
               # in all other cases there is nothing to do 
               #    $STATUS_VM_NOT_STARTED -> if VM is not started, there's no point to look for customization events 
               #    $STATUS_SUCCEEDED -> customization is already succeeded 
               #    $STATUS_FAILED -> customization 
               break; 
            } 
         } # enf of switch 
      } # end of the foreach loop 
      
      Write-Verbose -Message "Sleeping for $WAIT_INTERVAL_SECONDS seconds" -Verbose
      Start-Sleep -Seconds $WAIT_INTERVAL_SECONDS 
   } # end of while loop 
   
   # preparing result, without the helper column StartVMEvent 
   $result = $vmDescriptors | Select-Object VM,CustomizationStatus 
   $result
}
