using namespace System.Runtime.InteropServices

Set-Alias -Name pipelist -Value Get-PipeList
function Get-PipeList {
  [CmdletBinding()]param()

  begin {
    New-Structure LARGE_INTEGER {
      Int64  'QuadPart    0'
      UInt32 'LowPart     0'
      Int32  'iLowPart    0'
      Int32  'HighPart    4'
      UInt32 'dwHighPart  4'
    } -Explicit -PackingSize Size8

    New-Structure FILE_DIRECTORY_INFORMATION {
      UInt32 NextEntryOffset
      UInt32 FileIndex
      LARGE_INTEGER CreationTime
      LARGE_INTEGER LastAccessTime
      LARGE_INTEGER LastWriteTime
      LARGE_INTEGER ChangeTime
      LARGE_INTEGER EndOfFile
      LARGE_INTEGER AllocationSize
      UInt32 FileAttributes
      UInt32 FileNameLength
      String 'FileName ByValTStr 1'
    } -CharSet Unicode

    New-Structure PROCESS_BASIC_INFORMATION {
      Int32   ExitStatus
      IntPtr  PebAddress
      UIntPtr AffinityMask
      Int32   BasePriorirty
      IntPtr  UniqueProcessId
      IntPtr  InheritedFromUniqueProcessId
    }

    New-Structure FILE_PROCESS_IDS_USING_FILE_INFORMATION {
      UInt32   NumberOfProcessIdsInList
      IntPtr[] 'ProcessIdList ByValArray 1'
    }
    $out_, $to_i = [PROCESS_BASIC_INFORMATION].MakeByRefType(), "ToInt$(($psz = [IntPtr]::Size) * 8)"

    New-Delegate kernel32 {
      sfh CreateFileW([buf, int, IO.FileShare, ptr, IO.FileMode, int, ptr])
    }

    New-Delegate ntdll {
      int NtQueryDirectoryFile([sfh, ptr, ptr, ptr, buf, ptr, uint, uint, bool, ptr, bool])
      int NtQueryInformationFile([sfh, buf, buf, uint, uint])
      int NtQueryInformationProcess([ptr, uint, _out_, uint, buf])
    }

    $WithoutSysPrivileges = {
      end {
        $sihost, $out = (Get-Process sihost), [PROCESS_BASIC_INFORMATION]::new()
        [void]$ntdll.NtQueryInformationProcess.Invoke( # getting without check status
          $sihost.Handle, 0, [ref]$out, $out::GetSize(), $null
        )
        $sihost.Dispose()
        $out.InheritedFromUniqueProcessId.$to_i()
      }
    }
  }
  process {}
  end {
    if (($pipes = $kernel32.CreateFileW.Invoke(
      [buf].Uni('\\.\pipe\'), 0x80000000, [IO.FileShare]::Read,
      [IntPtr]::Zero, [IO.FileMode]::Open, 0, [IntPtr]::Zero
    )).IsInvalid) {
      throw [InvalidOperationException]::new('\\.\pipe\ is unavailable.')
    }

    $query, $isb = $true, [Byte[]]::new($psz * 2) # IO_STATUS_BLOCK
    try {
      $dir = [Marshal]::AllocHGlobal(0x1000)
      $lst = while (1) {
        if ($ntdll.NtQueryDirectoryFile.Invoke(
          $pipes, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero,
          $isb, $dir, 0x1000, 1, $false, [IntPtr]::Zero, $query
        ) -ne 0) {break}

        $tmp = $dir.$to_i()
        while (1) {
          $fdi = [IntPtr]$tmp -as [FILE_DIRECTORY_INFORMATION]
          [PSCustomObject]@{
            PipeName = ($name = [Marshal]::PtrToStringUni(
              [IntPtr]($tmp + $fdi::OfsOf('FileName')), $fdi.FileNameLength / 2
            ))
            CI = $fdi.EndOfFile.LowPart # instances
            MI = $fdi.AllocationSize.iLowPart # maximum of instances
            Handler = $($who = switch -regex ($name) {
              '.*mojo\.(\d+)\.\S+' {$matches[1]}
              'msys-\S+-(\S+)-.+'  {
                $nop, $res = $matches[1], 0
                [Int32]::TryParse($nop, [ref]$res) ? $(
                  Remove-Variable msys -ErrorAction 0 -Force
                  $local:msys = $nop
                  $res
                ) : $msys
              }
              'pipe_eventroot' { & $WithoutSysPrivileges }
              'winsock2\\.+-(\S+)-0' {[Int32]"0x$($matches[1])"}
              default {
                try {
                  if (($file = $kernel32.CreateFileW.Invoke(
                    [buf].Uni("\\.\pipe\$($name)"), 0, [IO.FileShare]::None,
                    [IntPtr]::Zero, [IO.FileMode]::Open, 0, [IntPtr]::Zero
                  )).IsInvalid) { throw [InvalidOperationException]::new('Pipe is not available.') }

                  $ids = [Byte[]]::new([FILE_PROCESS_IDS_USING_FILE_INFORMATION]::GetSize())
                  do {
                    if (($nts = $ntdll.NtQueryInformationFile.Invoke(
                      $file, $isb, $ids, $ids.Length, 47
                    )) -ne 0xC0000004) { break }
                    [Array]::Resize([ref]$ids, $ids.Length * 2)
                  } while ($nts -eq 0xC0000004) # STATUS_INFO_LENGTH_MISMATCH
                  (ConvertTo-PointerOrStructure $ids (
                    [FILE_PROCESS_IDS_USING_FILE_INFORMATION]
                  )).ProcessIdList.$to_i()
                }
                catch { Write-Verbose $_ }
                finally {
                  if ($file) { $file.Dispose() }
                  Write-Verbose "$($file.IsClosed)"
                }
              }
            };'{0} ({1})' -f ($who = Get-Process -Id $who).ProcessName, $who.Id)
          } # pipe

          if (!$fdi.NextEntryOffset) {break}
          $tmp += $fdi.NextEntryOffset
        }

        $query = $false
      }
    }
    catch { Write-Verbose $_ }
    finally { if ($dir) {[Marshal]::FreeHGlobal($dir)}}

    $pipes.Dispose()
    Write-Verbose "$($pipes.IsClosed)"
    Format-Table -InputObject $lst -AutoSize
  }
}

Export-ModuleMember -Alias pipelist -Function Get-PipeList
