Set-Alias -Name heap -Value Get-PsHeap
function Get-PsHeap {
  [CmdletBinding()]param($PSBoundParameters)

  begin {
    New-Structure RTL_DEBUG_INFORMATION {
      IntPtr   SectionHandleClient
      IntPtr   ViewBaseClient
      IntPtr   ViewBaseTarget
      UIntPtr  ViewBaseDelta
      IntPtr   EventPairClient
      IntPtr   EventPairTarget
      IntPtr   TargetProcessId
      IntPtr   TargetThreadHandle
      UInt32   Flags
      UIntPtr  OffsetFree
      UIntPtr  CommitSize
      UIntPtr  ViewSize
      IntPtr   ModulesUnion
      IntPtr   BackTraces
      IntPtr   Heaps
      IntPtr   Locks
      IntPtr   SpecificHeap
      IntPtr   TargetProcessHandle
      IntPtr   VerifierOptions
      IntPtr   ProcessHeap
      IntPtr   CriticalSectionHandle
      IntPtr   CriticalSectionOwnerThread
      IntPtr[] 'Reserved ByValArray 4'
    }

    New-Structure RTL_HEAP_INFORMATION {
      IntPtr   BaseAddress
      UInt32   Flags
      UInt16   EntryOverhead
      UInt16   CreatorBackTraceIndex
      UIntPtr  BytesAllocated
      UIntPtr  BytesCommitted
      UInt32   NumberOfTags
      UInt32   NumberOfEntries
      UInt32   NumberOfPseudoTags
      UInt32   PseudoTagGranularity
      UInt32[] 'Reserved ByValArray 5'
      IntPtr   Tags
      IntPtr   Entries
    }

    New-Structure RTL_PROCESS_HEAPS {
      UInt32   NumberOfHeaps
      RTL_HEAP_INFORMATION[] 'Heaps ByValArray 1'
    }

    New-Delegate ntdll {
      ptr RtlCreateQueryDebugBuffer([int, bool])
      int RtlDestroyQueryDebugBuffer([ptr])
      int RtlQueryProcessDebugInformation([ptr, uint, ptr])
    }
  }
  process {}
  end {
    New-PsProxy $PSBoundParameters -CallBack {
      [IntPtr]$ptr = [IntPtr]::Zero
      try {
        $ptr = $ntdll.RtlCreateQueryDebugBuffer.Invoke(0, $true)
        if ($ptr -eq [IntPtr]::Zero) {
          throw [InvalidOperationException]::new('Unnable query process information.')
        }

        if (($nts = $ntdll.RtlQueryProcessDebugInformation.Invoke($_.Id, 0x14, $ptr)) -ne 0) {
          throw [InvalidOperationException]::new((ConvertTo-ErrMessage -NtStatus $nts))
        }

        $tmp = ($ptr -as [RTL_DEBUG_INFORMATION]).Heaps."ToInt$([IntPtr]::Size * 8)"()
        $arr = ([IntPtr]$tmp) -as [RTL_PROCESS_HEAPS]
        $tmp += $arr::OfsOf('Heaps')
        $(for ($i = 0; $i -lt $arr.NumberOfHeaps; $i++) {
          Select-Object -InputObject (
            $inf = ([IntPtr]$tmp) -as [RTL_HEAP_INFORMATION]
          ) -Property @{N='BaseAddress';E={'0x{0:X}' -f $_.BaseAddress}
          }, BytesAllocated, BytesCommitted, NumberOfEntries, EntryOverhead
          $tmp += [RTL_HEAP_INFORMATION]::GetSize()
        }) | Format-Table -AutoSize
      }
      catch { Write-Verbose $_ }
      finally {
        if ($ptr -ne [IntPtr]::Zero) {
          if (($nts = $ntdll.RtlDestroyQueryDebugBuffer.Invoke($ptr)) -ne 0) {
            Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
          }
        }
      }
    }
  }
}

Export-ModuleMember -Alias heap -Function Get-PsHeap
