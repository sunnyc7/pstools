using namespace System.Runtime.InteropServices

function Get-ApiSet {
  [CmdletBinding()]param()

  begin {
    New-Structure API_SET_NAMESPACE {
      UInt32 Version
      UInt32 Size
      UInt32 Flags
      UInt32 Count
      UInt32 EntryOffset
      UInt32 HashOffset
      UInt32 HashFactor
    }

    New-Structure API_SET_NAMESPACE_ENTRY {
      UInt32 Flags
      UInt32 NameOffset
      UInt32 NameLength
      UInt32 HashedLength
      UInt32 ValueOffset
      UInt32 ValueCount
    }

    New-Structure API_SET_VALUE_ENTRY {
      UInt32 Flags
      UInt32 NameOffset
      UInt32 NameLength
      UInt32 ValueOffset
      UInt32 ValueLength
    }

    New-Delegate ntdll {
      ptr RtlGetCurrentPeb
    }

    $to_i = "ToInt$(($sz = [IntPtr]::Size) * 8)"
  }
  process {}
  end {
    $ptr = [Marshal]::ReadIntPtr([IntPtr]( # ApiSetMap offset
      $ntdll.RtlGetCurrentPeb.Invoke().$to_i() + ($sz -eq 8 ? 0x68 : 0x38)
    ))
    $asn, $mov = ($ptr -as [API_SET_NAMESPACE]), $ptr.$to_i()

    $pasne = [IntPtr]($asn.EntryOffset + $mov) # first entry pointer
    for ($i = 0; $i -lt $asn.Count; $i++) {
      $asne = $pasne -as [API_SET_NAMESPACE_ENTRY]
      $dll = [Marshal]::PtrToStringUni([IntPtr]($asne.NameOffset + $mov), $asne.NameLength / 2)
      $ses = [Boolean]$asne.Flags

      $pasve = [IntPtr]($asne.ValueOffset + $mov)
      $mod = for ($j = 0; $j -lt $asne.ValueCount; $j++) {
        $asve = $pasve -as [API_SET_VALUE_ENTRY]
        [Marshal]::PtrToStringUni([IntPtr]($asve.ValueOffset + $mov), $asve.ValueLength / 2)
        # move to the next value
        $pasve = [IntPtr]($pasve.$to_i() + $asve::GetSize())
      }

      [PSCustomObject]@{
        Module = "$dll.dll"
        Sealed = $ses
        Linked = $mod
      }
      # move to the next entry
      $pasne = [IntPtr]($pasne.$to_i() + $asne::GetSize())
    }
  }
}

Export-ModuleMember -Function Get-ApiSet
