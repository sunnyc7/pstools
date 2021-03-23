Set-Alias -Name clockres -Value Get-ClockRes
function Get-ClockRes {
  [CmdletBinding()]param()

  end {
    New-Delegate ntdll {
      int NtQueryTimerResolution([uint_, uint_, uint_])
    }
    $max, $min, $cur = [UInt32[]](,0 * 3)

    if (($nts = $ntdll.NtQueryTimerResolution.Invoke(
      [ref]$max, [ref]$min, [ref]$cur
    )) -ne 0) {
      Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
      return
    }

    ($zip = [Linq.Enumerable]::Zip(
      [String[]]('Maximum', 'Minimum', 'Current'),
      [String[]]($max, $min, $cur).ForEach{
        ' timer interval: {0:f3} ms' -f ($_ / 10000)
      }, [Func[String, String, String]]{$args[0] + $args[1]}
    ))
    $zip.Dispose()
  }
}

Export-ModuleMember -Alias clockres -Function Get-ClockRes
