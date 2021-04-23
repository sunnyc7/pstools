using namespace System.Runtime.InteropServices

Set-Alias -Name vadump -Value Get-PsVMInfo
function Get-PsVMInfo {
  [CmdletBinding()]param($PSBoundParameters)
  DynamicParam {
    New-DynParameter (@{
      Name  = 'Address'
      Type  = [IntPtr]
      Value = [IntPtr]::Zero
    })
  }

  begin {
    New-Enum MEM_PROTECT {
      PAGE_NOACCESS          = 0x00000001
      PAGE_READONLY          = 0x00000002
      PAGE_READWRITE         = 0x00000004
      PAGE_WRITECOPY         = 0x00000008
      PAGE_EXECUTE           = 0x00000010
      PAGE_EXECUTE_READ      = 0x00000020
      PAGE_EXECUTE_READWRITE = 0x00000040
      PAGE_EXECUTE_WRITECOPY = 0x00000080
      PAGE_GUARD             = 0x00000100
      PAGE_NOCACHE           = 0x00000200
      PAGE_WRITECOMBINE      = 0x00000400
    } -Type ([UInt32]) -Flags

    New-Enum MEM_STATE {
      MEM_COMMIT  = 0x00001000
      MEM_RESERVE = 0x00002000
      MEM_FREE    = 0x00010000
    } -Type ([UInt32])

    New-Enum MEM_TYPE {
      MEM_PRIVATE = 0x00020000
      MEM_MAPPED  = 0x00040000
      MEM_IMAGE   = 0x01000000
    } -Type ([UInt32])

    New-Structure MEMEORY_BASIC_INFORMATION {
      IntPtr  BaseAddress
      IntPtr  AllocationBase
      MEM_PROTECT AllocationProtect
      UIntPtr RegionSize
      MEM_STATE State
      MEM_PROTECT Protect
      MEM_TYPE Type
    }
    $out_ = [MEMEORY_BASIC_INFORMATION].MakeByRefType()

    New-Delegate ntdll {
      int NtQueryVirtualMemory([ptr, ptr, uint, _out_, uint, buf])
      int NtReadVirtualMemory([ptr, ptr, buf, uint, buf])
    }

    $fmt, $to_i, $to_u = "{0:X$(($sz = [IntPtr]::Size) * 2)}", "ToInt$($sz * 8)", "ToUInt$($sz * 8)"
    $sz, $ptr = [MEMEORY_BASIC_INFORMATION]::GetSize(), ($paramAddress.Value ?? [IntPtr]::Zero)
    $query =! ($ptr -eq [IntPtr]::Zero)
  }
  process {}
  end {
    New-PsProxy $PSBoundParameters -Callback {
      $out, $buf, $pnt = [MEMEORY_BASIC_INFORMATION]::new(), [Byte[]]::new(0x400), @{}
      $local:hndl = $_.Handle
      $local:_pid = $_.Id
      $pnt[([IntPtr]0x7FFE0000).$to_i()] = 'User Shared Data'
      foreach ($module in $_.Modules) {
        $pnt[($ba = $module.BaseAddress.$to_i())] = $module.ModuleName
        if (($nts = $ntdll.NtReadVirtualMemory.Invoke($hndl, $module.BaseAddress, $buf, $buf.Length, $null)) -ne 0) {
          Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
          continue
        }

        $gch = [GCHandle]::Alloc($buf, [GCHandleType]::Pinned)
        $ifh = [Marshal]::ReadInt32(($adr = $gch.AddrOfPinnedObject()), 0x3C)
        $sig = [BitConverter]::ToUInt16( # getting section names and their addresses
          [BitConverter]::GetBytes([Marshal]::ReadInt16($adr, $ifh + 0x04)), 0
        ), [Marshal]::ReadInt16($adr, $ifh + 0x06)
        $adr = $adr.$to_i() + $ifh + $(switch ($sig[0]) {0x014C {0x0F8} 0x8664 {0x108}})
        (0..($sig[1] - 1)).ForEach{
          $pnt[($ba + [Marshal]::ReadInt32([IntPtr]$adr, 0x0C))] = [Marshal]::PtrToStringAnsi([IntPtr]$adr, 0x08)
          $adr += 0x28
        }
        $gch.Free()
      }

      while (1) {
        if (($nts = $ntdll.NtQueryVirtualMemory.Invoke($hndl, $ptr, 0, [ref]$out, $sz, $null)) -ne 0) {
          Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
          break
        }
        $buf.Clear()
        if (($nts = $ntdll.NtReadVirtualMemory.Invoke($hndl, $ptr, $buf, $buf.Length, $null)) -ne 0) {
          Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
        }
        if (!$pnt.ContainsKey(($sig = $ptr.$to_i()))) {
          $pnt[$sig] = "[$(-join$buf[0..15].ForEach{$_ -in (33..122) ? [Char]$_ : '.'})]"
        }

        $dmp = [PSCustomObject]@{
          BaseAddress = $fmt -f ($ba = $out.BaseAddress.$to_i())
          EndAddress = $fmt -f ($ea = $ba + $out.RegionSize.$to_u())
          Type = $out.Type
          State = $out.State
          Protect = $out.Protect
          Point = $pnt[$ba]
        }
        $local:ptr = [IntPtr]$ea
        if ($query) {
          Add-Member -InputObject $dmp -MemberType NoteProperty -Name PID -Value $_pid
          Format-Hex -InputObject $buf
        }
        $dmp

        if ($query) {
          $local:ptr = $paramAddress.Value
          break
        }
      }
    } | Format-Table -AutoSize
  }
}

Export-ModuleMember -Alias vadump -Function Get-PsVMInfo
