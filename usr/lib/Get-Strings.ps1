using namespace System.IO
using namespace System.Text

Set-Alias -Name strings -Value Get-Strings
function Get-Strings {
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

    [Parameter()][Alias('b')][UInt32]$BytesToProcess = 0,
    [Parameter()][Alias('f')][UInt32]$BytesOffset    = 0,
    [Parameter()][Alias('n')][Byte]  $StringLength   = 3,
    [Parameter()][Alias('o')][Switch]$StringOffset,
    [Parameter()][Alias('u')][Switch]$Unicode
  )

  begin {
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
      $PipelineInput = !$PSBoundParameters.ContainsKey('Path')
    }

    function private:Find-Strings([FileInfo]$File) {
      process {
        try {
          $fs = [File]::OpenRead($File.FullName)
          # unable to read beyond file length
          if ($BytesToProcess -ge $fs.Length -or $BytesOffset -ge $fs.Length) {
            throw [InvalidOperationException]::new('Out of stream.')
          }
          # offset has been defined
          if ($BytesOffset -gt 0) {[void]$fs.Seek($BytesOffset, [SeekOrigin]::Begin)}
          # bytes to process
          $buf = [Byte[]]::new(($BytesToProcess -gt 0 ? $BytesToProcess : $fs.Length))
          [void]$fs.Read($buf, 0, $buf.Length)
          # show printable strings
          ([Regex]"[\x20-\x7E]{$StringLength,}").Matches(
            [Encoding]::"U$($Unicode.IsPresent ? 'nicode' : 'TF7')".GetString($buf)
          ).ForEach{
            $StringOffset ? '{0}:{1}' -f $_.Index, $_.Value : $_.Value
          }
        }
        catch {Write-Verbose $_}
        finally {
          if ($fs) {$fs.Dispose()}
        }
      }
    }
  }
  process {}
  end {
    $PSCmdlet.ParameterSetName -eq 'Path' ? (
      Find-Strings ($PipelineInput ? $Path : (Get-Item $Path -ErrorAction 0))
    ) : (Find-Strings (Get-Item -LiteralPath $LiteralPath))
  }
}

Export-ModuleMember -Alias strings -Function Get-Strings
