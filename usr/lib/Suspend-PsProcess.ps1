Set-Alias -Name psuspend -Value Suspend-PsProcess
function Suspend-PsProcess {
  [CmdletBinding()]param($PSBoundParameters)

  end {
    New-Delegate ntdll {
      int NtSuspendProcess([ptr])
    }

    New-PsProxy $PSBoundParameters -Callback {
      if ([Linq.Enumerable]::Sum([Int32[]](
        Select-Object -InputObject $_.Threads[0] -Property ThreadState, WaitReason
      ).PSObject.Properties.Value.ForEach{$_ -eq 5}) -ne 2) {
        if (($nts = $ntdll.NtSuspendProcess.Invoke($_.Handle)) -ne 0) {
          Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
        }
        else {Write-Verbose "Process $($_.Id) is suspended."}
      }
      else {Write-Verbose "Process $($_.Id) is already suspended."}
    }
  }
}

Export-ModuleMember -Alias psuspend -Function Suspend-PsProcess
