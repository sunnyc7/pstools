function Get-CpuCache {
  [CmdletBinding()]param()

  begin {
    New-Enum LOGICAL_PROCESSOR_RELATIONSHIP {
      RelationProcessorCore
      RelationNumaNode
      RelationCache
      RelationProcessorPackage
      RelationGroup
      RelationAll = 0xffff
    }

    New-Enum PROCESSOR_CACHE_TYPE {
      CacheUnified
      CacheInstruction
      CacheData
      CacheTrace
    }

    New-Structure PROCESSORCORE {
      Byte Flags
    }

    New-Structure NUMANODE {
      UInt32 NodeNumber
    }

    New-Structure CACHE_DESCRIPTOR {
      Byte   Level
      Byte   Associativity
      UInt16 LineSize
      UInt32 Size
      PROCESSOR_CACHE_TYPE Type
    }

    New-Structure SYSTEM_LOGICAL_PROCESSOR_INFORMATION_UNION {
      PROCESSORCORE 'ProcessorCore 0'
      NUMANODE 'NumaNode 0'
      CACHE_DESCRIPTOR 'Cache 0'
      UInt64 'Reserved 8'
    } -Explicit

    New-Structure SYSTEM_LOGICAL_PROCESSOR_INFORMATION {
      UIntPtr ProcessorMask
      LOGICAL_PROCESSOR_RELATIONSHIP Relationship
      SYSTEM_LOGICAL_PROCESSOR_INFORMATION_UNION ProcessorInformation
    }

    New-Delegate kernel32 {
      bool GetLogicalProcessorInformation([buf, uint_])
    }
  }
  process {}
  end {
    $bsz = 0 # first pass is required to retrieve real buffer size
    if (!$kernel32.GetLogicalProcessorInformation.Invoke($null, [ref]$bsz) -and !$bsz) {
      throw [InvalidOperationException]::new('Cannot retrieve buffer size')
    }

    $buf = [Byte[]]::new($bsz)
    if (!$kernel32.GetLogicalProcessorInformation.Invoke($buf, [ref]$bsz)) {
      throw [InvalidOperationException]::new('Internal error.')
    }

    (0..($bsz / ($sz = [SYSTEM_LOGICAL_PROCESSOR_INFORMATION]::GetSize()) - 1)).ForEach{
      $slpi = ConvertTo-PointerOrStructure $buf[0..($sz - 1)] (
        [SYSTEM_LOGICAL_PROCESSOR_INFORMATION]
      )
      if ($slpi.Relationship -eq 2) { $slpi.ProcessorInformation.Cache }
      $buf = $buf[$sz..$buf.Length]
    } | Format-Table -AutoSize
  }
}

Export-ModuleMember -Function Get-CpuCache
