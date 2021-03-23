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
    } -Flags

    New-Enum MEM_STATE {
      MEM_COMMIT  = 0x00001000
      MEM_RESERVE = 0x00002000
      MEM_FREE    = 0x00010000
    } -Flags

    New-Enum MEM_TYPE {
      MEM_PRIVATE = 0x00020000
      MEM_MAPPED  = 0x00040000
      MEM_IMAGE   = 0x01000000
    } -Flags

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
    }

    $sz = [IntPtr]::Size
    $fmt, $to_i, $to_u = "{0:X$($sz * 2)}", "ToInt$($sz * 8)", "ToUInt$($sz * 8)"
  }
  process {}
  end {
    New-PsProxy $PSBoundParameters -Callback {
      $out, $sz = [MEMEORY_BASIC_INFORMATION]::new(), [MEMEORY_BASIC_INFORMATION]::GetSize()
      if ($paramAddress.Value -ne 0) {
        if (($nts = $ntdll.NtQueryVirtualMemory.Invoke(
          $_.Handle, $paramAddress.Value, 0, [ref]$out, $sz, $null
        )) -ne 0) { Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts) }
        else {
          [PSCustomObject]@{
            BaseAddress = $fmt -f $out.BaseAddress.$to_i()
            AllocationBase = $fmt -f $out.AllocationBase.$to_i()
            AllocationProtect = $out.AllocationProtect
            RegionSize = $fmt -f $out.RegionSize.$to_u()
            State = $out.State
            Protect = $out.Protect
            Type = $out.Type
          }
        }
      }
      else {
        $ptr = [IntPtr]::Zero
        $(while (1) {
          if (($nts = $ntdll.NtQueryVirtualMemory.Invoke(
            $_.Handle, $ptr, 0, [ref]$out, $sz, $null
          )) -ne 0) {
            Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
            break
          }
          [PSCustomObject]@{
            BaseAddress = $fmt -f $out.BaseAddress.$to_i()
            AllocationBase = $fmt -f $out.AllocationBase.$to_i()
            AllocationProtect = $out.AllocationProtect
            RegionSize = $fmt -f $out.RegionSize.$to_u()
            State = $out.State
            Protect = $out.Protect
            Type = $out.Type
          }
          $ptr = [IntPtr]($out.BaseAddress.$to_i() + [Int64]$out.RegionSize.$to_u())
        }) | Format-Table -AutoSize
      }
    }
  }
}

Export-ModuleMember -Alias vadump -Function Get-PsVMInfo
