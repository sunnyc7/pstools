Set-Alias -Name pstree -Value Get-PsTree
function Get-PsTree {
  [CmdletBinding()]param()

  begin {
    New-Structure tagPROCESSENTRY32W {
      UInt32  dwSize
      UInt32  cntUsage
      UInt32  th32ProcessID
      UIntPtr th32DefaultHeapID
      UInt32  th32ModuleID
      UInt32  cntThreads
      UInt32  th32ParentProcessID
      Int32   pcPriClassBase
      UInt32  dwFlags
      String 'szExeFile ByValTStr 260'
    } -CharSet Unicode
    $out_ = [tagPROCESSENTRY32W].MakeByRefType()

    New-Delegate kernel32 {
      bool CloseHandle([ptr])
      ptr  CreateToolhelp32Snapshot([uint, uint])
      bool Process32FirstW([ptr, _out_])
      bool Process32NextW([ptr, _out_])
    }

    function Add-PsChild([PSCustomObject]$Process, [Int32]$Depth = 1) {
      end {
        $lst.Where{$_.PPID -eq $Process.PID -and $_.PPID -ne 0}.ForEach{
          "$("$([Char]32)" * 2 * $Depth)$($_.Name) ($($_.PID))"
          Add-PsChild $_ (++$Depth)
          $Depth--
        }
      }
    }
  }
  process {}
  end {
    try {
      $hndl = $kernel32.CreateToolhelp32Snapshot.Invoke(0x02, 0)
      $out = [tagPROCESSENTRY32W]::new()
      $out.dwSize = [tagPROCESSENTRY32W]::GetSize()
      if (!$kernel32.Process32FirstW.Invoke($hndl, [ref]$out)) {
        throw [InvalidOPerationException]::new('Cannot retrieve process information.')
      }
      $lst = do {
        [PSCustomObject]@{
          PID  = $out.th32ProcessID
          PPID = $out.th32ParentProcessID
          Name = $out.szExeFile
        }
      } while ($kernel32.Process32NextW.Invoke($hndl, [ref]$out))
      $lst.ForEach{
        if (!($ps = Get-Process -Id $_.PPID -ErrorAction 0) -or !$ps.Name -or $_.PPID -eq 0) {
          "$($_.Name) ($($_.PID))"
          Add-PsChild $_
        }
      }
    }
    catch { Write-Verbose $_ }
    finally {
      if ($hndl) {
        if (!$kernel32.CloseHandle.Invoke($hndl)) {
          throw [InvalidOPerationException]::new('Cannot release processes snapshot.')
        }
      }
    }
  }
}

Export-ModuleMember -Alias pstree -Function Get-PsTree
