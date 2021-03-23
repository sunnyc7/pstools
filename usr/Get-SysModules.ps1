using namespace System.Runtime.InteropServices

function Get-SysModules {
  [CmdletBinding()]param()

  begin {
    New-Delegate ntdll {
      int NtQuerySystemInformation([uint, ptr, uint, buf])
    }

    New-Structure RTL_PROCESS_MODULE_INFORMATION {
      IntPtr Section
      IntPtr MappedBase
      IntPtr ImageBase
      UInt32 ImageSize
      UInt32 Flags
      UInt16 LoadOrderIndex
      UInt16 InitOrderIndex
      UInt16 LoadCount
      UInt16 OffsetToFileName
      Char[] 'FullPathName ByValArray 256'
    }
  }
  process {}
  end {
    $STATUS_INFO_LENGTH_MISMATCH, $req = 0xC0000004, [Byte[]]::new(4)
    $STATUS_SUCCESS, $sysdir = 0, [Environment]::SystemDirectory

    if ($STATUS_INFO_LENGTH_MISMATCH -ne (
      $nts = $ntdll.NtQuerySystemInformation.Invoke(11, [IntPtr]::Zero, 0, $req)
    )) {
      Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
      return
    }

    try {
      $ptr = [Marshal]::AllocHGlobal(($sz = [BitConverter]::ToUInt32($req, 0)))
      if ($STATUS_SUCCESS -ne (
        $nts = $ntdll.NtQuerySystemInformation.Invoke(11, $ptr, $sz, $null)
      )) { throw (ConvertTo-ErrMessage -NtStatus $nts) }

      $psz, $sz = [IntPtr]::Size, [RTL_PROCESS_MODULE_INFORMATION]::GetSize()
      $num, $itr = [Marshal]::ReadInt32($ptr), ($ptr."ToInt$($psz * 8)"() + $psz)
      $(for ($i = 0; $i -lt $num; $i++) {
        $mod = ([IntPtr]$itr) -as [RTL_PROCESS_MODULE_INFORMATION]
        [PSCustomObject]@{
          Ord     = $mod.LoadOrderIndex
          Address = $mod.ImageBase.ToString("X$($psz * 2)")
          Size    = $mod.ImageSize
          #Flags   = $mod.Flags
          Count   = $mod.LoadCount
          Path    = [String]::new($mod.FullPathName
          ).Split("`0")[0] -replace '(?:\\)?.*system32', $sysdir
        }
        $itr += $sz
      }) | Format-Table -AutoSize
    }
    catch { Write-Verbose $_ }
    finally {
      if ($ptr) { [Marshal]::FreeHGlobal($ptr) }
    }
  }
}

Export-ModuleMember -Function Get-SysModules
