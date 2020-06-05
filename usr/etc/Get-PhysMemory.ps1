function Get-PhysMemory {
  [CmdletBinding()]param()

  begin {
    New-Structure SYSTEM_PHYSICAL_MEMORY_INFORMATION {
      UInt64 TotalPhysicalBytes
      UInt64 LowestPhysicalAddress
      UInt64 HighestPhysicalAddress
    }
    $out = [SYSTEM_PHYSICAL_MEMORY_INFORMATION].MakeByRefType()

    New-Delegate ntdll {
      int NtQuerySystemInformation([int, $out, int, buf])
    }
  }
  process {}
  end {
    $spmi = [SYSTEM_PHYSICAL_MEMORY_INFORMATION]::new()
    if (($nts = $ntdll.NtQuerySystemInformation.Invoke(
      184, [ref]$spmi, $spmi::GetSize(), $null
    )) -ne 0) {
      throw (ConvertTo-ErrMessage -NtStatus $nts)
    }
    $spmi
  }
}
