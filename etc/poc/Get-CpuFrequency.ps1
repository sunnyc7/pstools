function Get-CpuFrequency {
  [CmdletBinding()]param()

  begin {
    New-Delegate ntdll {
      int NtPowerInformation([int, ptr, int, buf, int])
    }

    New-Structure PROCESS_POWER_INFORMATION {
      UInt32 Number
      UInt32 MaxMhz
      UInt32 CurrentMhz
      UInt32 MhzLimit
      UInt32 MaxIdleState
      UInt32 CurrentIdleState
    }

    $sz = [PROCESS_POWER_INFORMATION]::GetSize()
  }
  process {}
  end {
    $buf = [Byte[]]::new($sz)
    while ($ntdll.NtPowerInformation.Invoke(
      11, [IntPtr]::Zero, 0, $buf, $buf.Length
    ) -eq 0xC0000023) {
      [Array]::Resize([ref]$buf, ($buf.Length * 2))
    }

    $(for ($i, $cores = 0, ($buf.Length / $sz); $i -lt $cores; $i++) {
      ConvertTo-PointerOrStructure $buf[0..($sz - 1)] ([PROCESS_POWER_INFORMATION])
      $buf = $buf[$sz..$buf.Length]
    }) | Format-Table -AutoSize
  }
}
