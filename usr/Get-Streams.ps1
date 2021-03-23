using namespace System.Runtime.InteropServices

Set-Alias -Name streams -Value Get-Streams
function Get-Streams {
  [CmdletBinding(DefaultParameterSetName='Path')]
  param(
    [Parameter(Mandatory,
               ParameterSetName='Path',
               Position=0,
               ValueFromPipeline,
               ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    [String]$Path,

    [Parameter(Mandatory,
               ParameterSetName='LiteralPath',
               Position=0,
               ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Alias('PSPath')]
    [String]$LiteralPath,

    [Parameter()][Switch]$Delete
  )

  begin {
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
      $PipelineInput = !$PSBoundParameters.ContainsKey('Path')
    }

    function private:Find-Streams([Object]$Target) {
      process {
        New-Structure FILE_STREAM_INFORMATION {
          UInt32 NextEntryOffset
          UInt32 StreamNameLength
          Int64  StreamSize
          Int64  StreamAllocationSize
          String 'StreamName ByValTStr 1'
        } -CharSet Unicode

        New-Delegate kernel32 {
          sfh CreateFileW([buf, int, IO.FileShare, ptr, IO.FileMode, int, ptr])
        }

        New-Delegate ntdll {
          int NtQueryInformationFile([sfh, buf, ptr, int, int])
        }

        if (($sfh = $kernel32.CreateFileW.Invoke(
          [buf].Uni($Target), 0x80000000, [IO.FileShare]::Read, [IntPtr]::Zero,
          [IO.FileMode]::Open, 0x02000000, [IntPtr]::Zero
        )).IsInvalid) {
          throw [InvalidOperationException]::new('Unavailable file system object.')
        }

        $sz, $isb = 0x400, [Byte[]]::new([IntPtr]::Size * 2) # IO_STATUS_BLOCK
        try {
          $ptr = [Marshal]::AllocHGlobal($sz)

          while ($ntdll.NtQueryInformationfile.Invoke($sfh, $isb, $ptr, $sz, 0x16) -ne 0) {
            $ptr = [Marshal]::ReAllocHGlobal($ptr, [IntPtr]($sz *= 2))
          }

          $tmp = $ptr."ToInt$([IntPtr]::Size * 8)"()
          for ($i = 0;;) {
            # prevent CLR (op_Implicit) exception
            if ([Marshal]::ReadInt32([IntPtr]$tmp) -lt 0) {break}
            $fsi = ([IntPtr]$tmp) -as [FILE_STREAM_INFORMATION]
            if (($name = [Marshal]::PtrToStringUni(
              [IntPtr]($tmp + $fsi::OfsOf('StreamName')), $fsi.StreamNameLength / 2
            )) -ne '::$DATA') {
              [PSCustomObject]@{
                Name = $name
                Size = $fsi.StreamSize
                Allocation = $fsi.StreamAllocationSize
              }

              if ($Delete) {
                $stream = "$(Get-Item $Target)$([Regex]::Match($name, '^:([^:]*)').Value)"
                if (Test-Path $stream) {Remove-Item $stream -Force}
              }
              ++$i # stream found
            }

            if ($fsi.NextEntryOffset -eq 0) {break}
            $tmp += $fsi.NextEntryOffset
          }
        }
        catch {Write-Verbose $_}
        finally {
          if ($ptr) {[Marshal]::FreeHGlobal($ptr)}
        }

        $sfh.Dispose()
        Write-Verbose "$($sfh.IsClosed)"
        "$('-' * 13)`n`e[35;1mTotally found`e[0m`: $i stream(s)."
      }
    }
  }
  process {}
  end {
    $PSCmdlet.ParameterSetName -eq 'Path' ? (
      Find-Streams ($PipelineInput ? $Path : (Get-Item $Path -ErrorAction 0))
    ) : (Find-Streams (Get-Item -LiteralPath $LiteralPath))
  }
}

Export-ModuleMember -Alias streams -Function Get-Streams
