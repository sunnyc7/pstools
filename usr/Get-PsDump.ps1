Set-Alias -Name psdump -Value Get-PsDump
function Get-PsDump {
  [CmdletBinding()]param($PSBoundParameters)
  DynamicParam {
    New-DynParameter (@{
      Name = 'DumpType'
      Type = [String]
      Value = 'MiniDump'
      ValidateSet = ('MiniDump', 'FullDump')
      ValidateNotNullOrEmpty = $true
    }, @{
      Name = 'SavePath'
      Type = [String]
      Value = $pwd.Path
      ValidateScript = {Test-Path $_}
      ValidateNotNullOrEmpty = $true
    })
  }

  end {
    New-Delegate dbghelp {
      bool MiniDumpWriteDump([ptr, uint, sfh, uint, ptr, ptr, ptr])
    }

    New-PsProxy $PSBoundParameters -Callback {
      $dmp = "$(Resolve-Path $paramSavePath.Value)\$($_.Name)_$($_.Id).dmp"
      try {
        $fs = [IO.File]::Create($dmp)
        if (!$dbghelp.MiniDumpWriteDump.Invoke(
          $_.Handle, $_.Id, $fs.SafeFileHandle,
          ($paramDumpType.Value -eq 'MiniDump' ? 261 : 6),
          [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero
        )) {
          $err = $true
          throw [InvalidOperationException]::new("Dumping failure PID: $($_.Id)")
        }
      }
      catch { Write-Verbose $_ }
      finally {
        if ($fs) {$fs.Dispose()}
        if ($err) {Remove-Item $dmp -Force}
      }
    }

    $dbghelp.Dispose()
  }
}

Export-ModuleMember -Alias psdump -Function Get-PsDump
