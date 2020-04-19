using namespace System.Runtime.InteropServices

Set-Alias -Name handle -Value Get-PsHandle
function Get-PsHandle {
  [CmdletBinding()]param($PSBoundParameters)

  begin {
    New-Delegate kernel32 {
      bool CloseHandle([ptr])
      uint QueryDosDeviceW([buf, buf, uint])
    }

    New-Delegate ntdll {
      int NtDuplicateObject([ptr, ptr, ptr, ptr_, uint, bool, uint])
      int NtQueryInformationProcess([ptr, uint, ptr, uint, buf])
      int NtQueryObject([ptr, uint, ptr, uint, buf])
    }

    New-Structure PROCESS_HANDLE_TABLE_ENTRY_INFO {
      IntPtr HandleValue
      IntPtr HandleCount
      IntPtr PointerCount
      UInt32 GrantedAccess
      UInt32 ObjectTypeIndex
      UInt32 HandleAttributes
      UInt32 Reserved
    }

    New-Structure PROCESS_HANDLE_SNAPSHOT_INFORMATION {
      IntPtr NumberOfHandles
      IntPtr Reserved
      PROCESS_HANDLE_TABLE_ENTRY_INFO Handles
    }

    New-Structure UNICODE_STRING {
      UInt16 Length
      UInt16 MaximumLength
      String 'Buffer LPWstr'
    } -CharSet Unicode

    function Get-ObjectProperty([IntPtr]$h, [UInt32]$p) {
      try {
        $buf = [Marshal]::AllocHGlobal(0x1000)
        if (($nts = $ntdll.NtQueryObject.Invoke($h, $p, $buf, 0x1000, $null)) -ne 0) {
          throw [InvalidOperationException]::new("NTSTATUS 0x$($nts.ToString('x8'))")
        }
        ($buf -as [UNICODE_STRING]).Buffer
      }
      catch {Write-Verbose $_}
      finally { if ($buf) {[Marshal]::FreeHGlobal($buf)}}
    }

    $buf, $drives = [Byte[]]::new(0x100), @{}
    ([IO.DriveInfo]::GetDrives().Name.Trim('\')).ForEach{
      $buf.Clear()
      if ($kernel32.QueryDosDeviceW.Invoke(
        [Text.Encoding]::Unicode.GetBytes($_), $buf, 0x100
      )) {$drives[[Text.Encoding]::Unicode.GetString($buf).Trim("`0")] = $_}
    }
  }
  process {}
  end {
    New-PsProxy $PSBoundParameters -Callback {
      try {
        $ptr = [Marshal]::AllocHGlobal(($bsz = 0x1000))
        while ($ntdll.NtQueryInformationProcess.Invoke($_.Handle, 51, $ptr, $bsz, $null)) {
          $ptr = [Marshal]::ReAllocHGlobal($ptr, [IntPtr]($bsz *= 2))
        }

        $tmp, $hndl = $ptr.($to_i = "ToInt$([IntPtr]::Size * 8)")(), $_.Handle
        $snap = [IntPtr]$tmp -as [PROCESS_HANDLE_SNAPSHOT_INFORMATION]
        $tmp += $snap::OfsOf('Handles')
        (0..($snap.NumberOfHandles - 1)).ForEach{
          $entry = [IntPtr]$tmp -as [PROCESS_HANDLE_TABLE_ENTRY_INFO]
          [IntPtr]$duple = [IntPtr]::Zero
          if ($ntdll.NtDuplicateObject.Invoke(
              $hndl, $entry.HandleValue, [IntPtr]-1, [ref]$duple, 0, $false, 0x02
          ) -eq 0) {
            $h_type = Get-ObjectProperty $duple 2
            $h_name = Get-ObjectProperty $duple 1

            if ($h_type -eq 'file' -and $h_name -cmatch 'HarddiskVolume') {
              $pattern = $h_name.Substring(0, $h_name.IndexOf('\', 8))
              $h_name = $h_name -replace ($pattern -replace '\\', '\\'), $drives.$pattern
            }

            if ($h_type -eq 'key') {
              $h_name = switch -regex -casesensitive ($h_name) {
                'MACHINE' { $h_name -replace '\\REGISTRY\\MACHINE', 'HKLM' }
                'USER'    { $h_name -replace '\\REGISTRY\\USER', 'HKCU'}
                default   { $h_name }
              }
            }

            [PSCustomObject]@{
              Value = '0x{0:X}' -f $entry.HandleValue.$to_i()
              Type  = $h_type
              Name  = $h_name
            }

            if (!$kernel32.CloseHandle.Invoke($duple)) {
              Write-Verbose "Cannot close $($duple.$to_i()) duple."
            }
          }

          $tmp += $entry::GetSize()
        }.Where{![String]::IsNullOrEmpty($_.Name)}
      }
      catch {Write-Verbose $_}
      finally {if ($ptr) {[Marshal]::FreeHGlobal($ptr)}}
    }
  }
}

Export-ModuleMember -Alias handle -Function Get-PsHandle
