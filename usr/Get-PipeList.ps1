using namespace System.Runtime.InteropServices

Set-Alias -Name pipelist -Value Get-PipeList
function Get-PipeList {
  [CmdletBinding()]param()

  begin {
    New-Delegate kernel32 {
      sfh CreateFileW([buf, int, IO.FileShare, ptr, IO.FileMode, int, ptr])
    }

    New-Delegate ntdll {
      int NtQueryDirectoryFile([sfh, ptr, ptr, ptr, buf, ptr, uint, uint, bool, ptr, bool])
    }

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
  }
  process {}
  end {
    if (($pipes = $kernel32.CreateFileW.Invoke(
      [buf].Uni('\\.\pipe\'), 0x80000000, [IO.FileShare]::Read,
      [IntPtr]::Zero, [IO.FileMode]::Open, 0, [IntPtr]::Zero
    )).IsInvalid) {
      throw [InvalidOperationException]::new('\\.\pipe\ is unavailable.')
    }

    $query, $isb = $true, [Byte[]]::new([IntPtr]::Size * 2) # IO_STATUS_BLOCK
    try {
      $dir = [Marshal]::AllocHGlobal(0x1000)
      while (1) {
        if ($ntdll.NtQueryDirectoryFile.Invoke(
          $pipes, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero,
          $isb, $dir, 0x1000, 1, $false, [IntPtr]::Zero, $query
        ) -ne 0) {break}

        $tmp = $dir."ToInt$([IntPtr]::Size * 8)"()
        while (1) {
          $fdi = [IntPtr]$tmp -as [FILE_DIRECTORY_INFORMATION]
          [PSCustomObject]@{
            PipeName = [Marshal]::PtrToStringUni(
              [IntPtr]($tmp + $fdi::OfsOf('FileName')), $fdi.FileNameLength / 2
            )
            Instances = $fdi.EndOfFile.LowPart
            MaxInstances = $fdi.AllocationSize.iLowPart
          }

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
  }
}

Export-ModuleMember -Alias pipelist -Function Get-PipeList
