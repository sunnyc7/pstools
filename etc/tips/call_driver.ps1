using namespace System.Runtime.InteropServices

function Invoke-Beep {
  [CmdletBinding()]param()

  begin {
    New-Delegate kernelbase {
      bool CloseHandle([ptr])
      bool DeviceIoControl([ptr, uint, buf, uint, ptr, uint, buf, ptr])
    }

    New-Delegate ntdll {
      void RtlInitUnicodeString([buf, buf])
      int  NtCreateFile([ptr_, int, buf, buf, ptr, uint, uint, uint, uint, ptr, uint])
    }
  }
  process {}
  end {
    $uni = [Byte[]]::new(($psz = [IntPtr]::Size) * 2) # UNICODE_STRING
    $ntdll.RtlInitUnicodeString.Invoke($uni, [buf].Uni('\Device\Beep'))
    $isb = [Byte[]]::new($psz * 2) # IO_STATUS_BLOCK

    try {
      $gch = [GCHandle]::Alloc($uni, [GCHandleType]::Pinned)
      [Byte[]]$obj = [BitConverter]::GetBytes($psz * 6)  + (
        ,0 * (($psz -eq 8 ? 4 : 0) + $psz) # OBJECT_ATTRIBUTES initialization
      ) + [BitConverter]::GetBytes(
        $gch.AddrOfPinnedObject()."ToInt$($psz * 8)"()
      ) + (,0 * ($psz * 3))

      $hndl = [IntPtr]::Zero
      if (($nts = $ntdll.NtCreateFile.Invoke(
        [ref]$hndl, 0x80000000, $obj, $isb, [IntPtr]::Zero, 128, 1, 3, 0, [IntPtr]::Zero, 0
      )) -ne 0) { throw (ConvertTo-ErrMessage -NtStatus $nts) }

      [Byte[]]$beep = [BitConverter]::GetBytes(0x400) + [BitConverter]::GetBytes(0x2BC)
      $ret = [Byte[]]::new([Marshal]::SizeOf([UInt32]0))
      [void]$kernelbase.DeviceIoControl.Invoke(
        $hndl, (1 -shl 16), $beep, $beep.Length, [IntPtr]::Zero, 0, $ret, [IntPtr]::Zero
      )
    }
    catch { Write-Verbose $_ }
    finally {
      if ($hndl -and $hndl -ne [IntPtr]::Zero) {
        if (!$kernelbase.CloseHandle.Invoke($hndl)) {
          Write-Warning 'device has not been released.'
        }
      }
      if ($gch) { $gch.Free() }
    }
  }
}
