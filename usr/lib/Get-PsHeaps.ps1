using namespace System.Runtime.InteropServices

Set-Alias -Name heaps -Value Get-PsHeaps
function Get-PsHeaps {
  [CmdletBinding()]param($PSBoundParameters)

  begin {
    New-Structure RTL_DEBUG_INFORMATION {
      IntPtr  SectionClientHandle
      IntPtr  ViewBaseClient
      IntPtr  ViewBaseTarget
      UIntPtr ViewBaseDelta
      IntPtr  EventPairClient
      IntPtr  EventPairTarget
      IntPtr  TargetProcessId
      IntPtr  TargetThreadHandle
      UInt32  Flags
      UIntPtr OffsetFree
      UIntPtr CommitSize
      UIntPtr ViewSize
      IntPtr  Modules # union
      IntPtr  BackTraces
      IntPtr  Heaps
      IntPtr  Locks
      IntPtr  SpecificHeap
      IntPtr  TargetProcessHandle
      IntPtr  VerifierOptions
      IntPtr  ProcessHeap
      IntPtr  CriticalSectionHandle
      IntPtr  CriticalSectionOwnerThread
      IntPtr[] 'Reserved ByValArray 4'
    }

    New-Structure RTL_HEAP_INFORMATION {
      IntPtr  BaseAddress
      UInt32  Flags
      UInt16  EntryOverhead
      UInt16  CreatorBackTraceIndex
      UIntPtr BytesAllocated
      UIntPtr BytesCommitted
      UInt32  NumberOfTags
      UInt32  NumberOfEntries
      UInt32  NumberOfPseudoTags
      UInt32  PseudaoTagGranularity
      UInt32[] 'Reserved ByValArray 5'
      IntPtr  Tags
      IntPtr  Entries
    }

    New-Structure _heap_s1 {
      UIntPtr Settable
      UInt32  Tag
    }

    New-Structure _heap_s2 {
      UIntPtr CommittedSize
      IntPtr  FirstBlock
    }

    New-Structure _heap_u {
      _heap_s1 's1 0'
      _heap_s2 's2 0'
    } -Explicit

    New-Structure RTL_HEAP_ENTRY {
      UIntPtr Size
      UInt16  Flags
      UInt16  AllocatorBackTraceIndex
      _heap_u u
    }

    New-Delegate ntdll {
      ptr RtlCreateQueryDebugBuffer([uint, bool])
      int RtlDestroyQueryDebugBuffer([ptr])
      int RtlQueryProcessDebugInformation([ptr, uint, ptr])
    }

    $to_i = "ToInt$(($isz = [IntPtr]::Size) * 8)"
    $to_u = "ToUInt$(($usz = [UIntPtr]::Size) * 8)"
    $ifmt, $ufmt = "X$($isz * 2)", "X$($usz * 2)"
    $sz1,$sz2 = [RTL_HEAP_INFORMATION]::GetSize(), [RTL_HEAP_ENTRY]::GetSize()
  }
  process {}
  end {
    New-PsProxy $PSBoundParameters -Callback {
      try {
        $buf = $ntdll.RtlCreateQueryDebugBuffer.Invoke(0, $true)

        if (0 -ne ($nts = $ntdll.RtlQueryProcessDebugInformation.Invoke(
          ([IntPtr]$_.Id), 0x14, $buf
        ))) { throw (ConvertTo-ErrMessage -NtStatus $nts) }

        $ptr = ($buf -as [RTL_DEBUG_INFORMATION]).Heaps.$to_i()
        $num = [Marshal]::ReadInt32([IntPtr]$ptr)
        $ptr += $isz
        for ($i = 0; $i -lt $num; $i++) {
          $heap = ([IntPtr]$ptr) -as [RTL_HEAP_INFORMATION]
          $segs = $heap.Entries.$to_i()
          [PSCustomObject]@{
            Address   = $heap.BaseAddress.ToString($ufmt)
            Allocated = $heap.BytesAllocated
            Committed = $heap.BytesCommitted
            Entries   = $heap.NumberOfEntries
            Segments  = $(for ($j = 0; $j -lt $heap.NumberOfEntries; $j++) {
              if (($entry = ([IntPtr]$segs) -as [RTL_HEAP_ENTRY]).Flags -band 0x02) {
                $entry.u.s2.FirstBlock.ToString($ifmt)
              }
              $segs += $sz2
            })
          }
          $ptr += $sz1
        }
      }
      catch { Write-Verbose $_ }
      finally {
        if ($buf) {
          if (0 -ne ($nts = $ntdll.RtlDestroyQueryDebugBuffer.Invoke($buf))) {
            Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
          }
        }
      }
    } # proxy
  }
}

Export-ModuleMember -Alias heaps -Function Get-PsHeaps
