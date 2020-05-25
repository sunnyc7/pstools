function Get-Uptime {
  [CmdletBinding()]param()

  begin {
    New-Delegate ntdll {
      int NtQuerySystemInformation([int, buf, int, buf])
    }

    New-Structure SYSTEM_TIMEOFDAY_INFORMATION {
      Int64  BootTime
      Int64  CurrentTime
      Int64  TimeZoneBias
      UInt32 TimeZondeId
      UInt32 Reserved
      UInt64 BootTimeBias
      UInt64 SleepTimeBias
    }
  }
  process {}
  end {
    $buf = [Byte[]]::new([SYSTEM_TIMEOFDAY_INFORMATION]::GetSize())
    if (($nts = $ntdll.NtQuerySystemInformation.Invoke(3, $buf, $buf.Length, $null)) -ne 0) {
      throw (ConvertTo-ErrMessage -NtStatus $nts)
    }

    $sti = ConvertTo-PointerOrStructure $buf ([SYSTEM_TIMEOFDAY_INFORMATION])
    [TimeSpan]::FromMilliseconds(($sti.CurrentTime - $sti.BootTime) / 10000)
  }
}
