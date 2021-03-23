Set-Alias -Name psresume -Value Resume-PsProcess
function Resume-PsProcess {
  [CmdletBinding()]param($PSBoundParameters)

  end {
    New-Delegate ntdll {
      int NtResumeProcess([ptr])
    }

    New-PsProxy $PSBoundParameters -Callback {
      if ([Linq.Enumerable]::Sum([Int32[]](
        Select-Object -InputObject $_.Threads[0] -Property ThreadState, WaitReason
      ).PSObject.Properties.Value.ForEach{$_ -eq 5}) -eq 2) {
        if (($nts = $ntdll.NtResumeProcess.Invoke($_.Handle)) -ne 0) {
          Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
        }
        else {Write-Verbose "Process $($_.Id) is resumed."}
      }
      else {Write-Verbose "Process $($_.Id) is already active."}
    }
  }
}

Export-ModuleMember -Alias psresume -Function Resume-PsProcess
