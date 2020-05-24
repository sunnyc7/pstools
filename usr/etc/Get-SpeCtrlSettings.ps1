function Get-SpecCtrlSettings {
  [CmdletBinding()]param()

  begin {
    New-Delegate ntdll {
      int NtQuerySystemInformation([int, buf, int, buf])
		}

    $buf = [Byte[]](,0 * 4) # [Byte[]]::new([Marshal]::SizeOf([UInt32]0))
    # SystemKernelVaShadowInformation = 0n196
    if (($nts = $ntdll.NtQuerySystemInformation.Invoke(196, $buf, $buf.Length, $null)) -ne 0) {
      throw (ConvertTo-ErrMessage -NtStatus $nts)
		}
    $ks = ConvertTo-BitMap -Value ([BitConverter]::ToUInt32($buf, 0)) -BitMap {
       KvaShadowEnabled           : 1
       KvaShadowUserGlobal        : 1
       KvaShadowPcid              : 1
       KvaShadowInvpcid           : 1
       KvaShadowRequired          : 1
       KvaShadowRequiredAvailable : 1
       Reserved                   : 26
		}

    $buf.Clear() # using same buffer, simply clear it
    # SystemSpeculationControlInformation = 0n201
    if (($nts = $ntdll.NtQuerySystemInformation.Invoke(201, $buf, $buf.Length, $null)) -ne 0) {
      throw (ConvertTo-ErrMessage -NtStatus $nts)
		}
    $sc = ConvertTo-BitMap -Value ([BitConverter]::ToUInt32($buf, 0)) -BitMap {
       BpbEnabled                               : 1
       BpbDisabledSystemPolicy                  : 1
       BpbDisabledNoHardwareSupport             : 1
       SpecCtrlEnumerated                       : 1
       SpecCmdEnumerated                        : 1
       IbrsPresent                              : 1
       StibpPresent                             : 1
       SmepPresent                              : 1
       SpeculativeStoreBypassDisableAvailable   : 1
       SpeculativeStoreBypassDisableSupported   : 1
       SpeculativeStoreBypassDisabledSystemWide : 1
       SpeculativeStoreBypassDisabledKernel     : 1
       SpeculativeStoreBypassDisableRequired    : 1
       BpbDisabledKernelToUser                  : 1
       SpecCtrlRetpolineEnabled                 : 1
       SpecCtrlImportOptimizationEnabled        : 1
       EnhancedIbrs                             : 1
       HvL1tfStatusAvailable                    : 1
       HvL1tfProcessorNotAffected               : 1
       HvL1tfMigitationEnabled                  : 1
       HvL1tfMigitationNotEnabled_Hardware      : 1
       HvL1tfMigitationNotEnabled_LoadOption    : 1
       HvL1tfMigitationNotEnabled_CoreScheduler : 1
       EnhancedIbrsReported                     : 1
       MdsHardwareProtected                     : 1
       MbClearEnabled                           : 1
       MbClearReported                          : 1
       TsxCtrlStatus                            : 2
       TsxCtrlReported                          : 1
       TaaHardwareImmune                        : 1
       Reserved                                 : 1
		}
	}
  process {}
  end {
    $ks
    ''
    $sc
	}
}
