Set-Alias -Name clpws -Value Clear-PsWorkingSet
function Clear-PsWorkingSet {
  [CmdletBinding()]param($PSBoundParameters)

  end {
    New-Delegate kernel32 {
      bool SetProcessWorkingSetSize([ptr, int, int])
    }

    New-PsProxy $PSBoundParameters -Callback {
      !$_.Handle ? (
        Write-Verbose "$($_.ProcessName) ($(
          $_.Id)): cannot clear working set."
      ) : (
        "$($_.ProcessName) ($($_.Id
        )) : {0}" -f $kernel32.SetProcessWorkingSetSize.Invoke(
        $_.Handle, -1, -1
      ))
    }
  }
}

Export-ModuleMember -Alias clpws -Function Clear-PsWorkingSet
