('lib', 'usr\lib').ForEach{
  (Get-ChildItem -Path "$PSScriptRoot\$_" -Filter *.ps1).ForEach{.$_.FullName}
}

<#
class fmt {
  [String]$hex
  [String]$dec
  [String]$oct
  [String]$bin
  [String]$time
  [String]$double

  fmt([Int64]$v) {
    $this.hex = [Convert]::ToString($v, 16).PadLeft([IntPtr]::Size * 2, '0')
    $this.dec = $v
    $this.oct = [Convert]::ToString($v, 8).PadLeft(22, '0')
    $this.bin = [Linq.Enumerable]::Reverse([BitConverter]::GetBytes($v)).ForEach{
      [Convert]::ToString($_, 2).PadLeft(8, '0')
    }
    $this.time = try {
      $v -gt [UInt32]::MaxValue ? [DateTime]::FromFileTime($v)
                            : ([DateTime]'1.1.1970').AddSeconds($v).ToLocalTime()
    } catch { $_; 'n/a' }
    $this.double = '{0:G6}' -f [BitConverter]::Int64BitsToDouble($v)
  }
}
#>
