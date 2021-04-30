using namespace System.IO
using namespace System.Runtime.InteropServices

function Find-Links {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({!!($script:f = Get-Item $_ -ErrorAction 0)})]
    [SupportsWildcards()]
    [String]$Path
  )

  begin {
    New-Structure BY_HANDLE_FILE_INFORMATION {
      UInt32 dwFileAttributes
      Runtime.InteropServices.ComTypes.FILETIME ftCreationTime
      Runtime.InteropServices.ComTypes.FILETIME ftLastAccessTime
      Runtime.InteropServices.ComTypes.FILETIME ftLastWriteTime
      UInt32 dwVolumeSerialNumber
      UInt32 nFileSizeHigh
      UInt32 nFileSizeLow
      UInt32 nNumberOfLinks
      UInt32 nFileIndexHigh
      UInt32 nFileIndexLow
    } -PackingSize Size4
    $out_ = [BY_HANDLE_FILE_INFORMATION].MakeByRefType()

    New-Delegate kernelbase {
      bool FindClose([ptr])
      ptr  FindFirstFileNameW([buf, uint, uint_, buf])
      bool FindNextFileNameW([ptr, uint_, buf])
      bool GetFileInformationByHandle([ptr, _out_])
    }

    New-Delegate ntdll {
      ptr RtlGetCurrentPeb
    }
  }
  process {}
  end {
    $BitField = ConvertTo-BitMap -Value ([Marshal]::ReadByte($ntdll.RtlGetCurrentPeb.Invoke(), 0x03)) -BitMap {
      ImageUsesLargePages          : 1
      IsProtectedProcess           : 1
      IsImageDynamicallyRelocated  : 1
      SkipPatchingUser32Forwarders : 1
      IsPackagedProcess            : 1
      IsAppContainer               : 1
      IsProtectedProcessLight      : 1
      IsLongPathAwareProcess       : 1
    }

    $buf = [Byte[]]::new($BitField.IsLongPathAwareProcess -eq 0 ? 0x0104 : 0x7FFF)
    $ret = $buf.Length

    try {
      $sfh = [File]::Open($f.FullName, [FileMode]::Open, [FileAccess]::Read, [FileShare]::Read)
      $out = [BY_HANDLE_FILE_INFORMATION]::new()
      if (!$kernelbase.GetFileInformationByHandle.Invoke($sfh.Handle, [ref]$out)) {
        throw [InvalidOPerationException]::new('Cannot retrieve file information.')
      }
      if (($nl = $out.nNumberOfLinks) -le 1) { throw [InvalidOPerationException]::new('File has not hard links.') }
      $fff = $kernelbase.FindFirstFileNameW.Invoke([buf].Uni($f.FullName), 0, [ref]$ret, $buf)
      $chr = "$([Char]32)`u{251C}", "$([Char]32)`u{2514}"
      "`e[7m$($f.FullName) (index: 0x$($out.nFileIndexLow.ToString('X8')), links: $nl)`e[0m"
      do {
        "$(--$nl -ne 0 ? $chr[0] : $chr[1])$([buf].StrU($buf))"
        $buf.Clear() # releasing artifacts
        $ret = $buf.Length
      } while ($kernelbase.FindNextFileNameW.Invoke($fff, [ref]$ret, $buf))
    }
    catch { Write-Verbose $_ }
    finally {
      if ($fff) { if (!$kernelbase.FindClose.Invoke($fff)) { Write-Verbose 'Resourses has not been released.' } }
      if ($sfh) { $sfh.Dispose() }
    }
  }
}

Export-ModuleMember -Function Find-Links
