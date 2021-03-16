class fmt {
  [String]$hex
  [String]$dec
  [String]$oct
  [String]$bin
  [String]$chr
  [String]$time
  [String]$float
  [String]$double

  fmt ([Int64]$v) {
    $bytes = [BitConverter]::GetBytes($v)

    $this.hex = [Convert]::ToString($v, 16).PadLeft([IntPtr]::Size * 2, '0')
    $this.dec = $v
    $this.oct = [Convert]::ToString($v, 8).PadLeft(22, '0')
    $this.bin = ($$ = [Linq.Enumerable]::Reverse($bytes)).ForEach{
      [Convert]::ToString($_, 2).PadLeft(8, '0')
    }
    $this.chr = -join$$.ForEach{$_ -in (33..122) ? [Char]$_ : '.'}
    $this.time = try {
      $v -gt [UInt32]::MaxValue ? [DateTime]::FromFileTime($v)
                       : ([DateTime]'1.1.1970').AddSeconds($v).ToLocalTime()
    } catch { $_; 'n/a' }
    $this.float = 'low {0:G6} high {1:G6}' -f (
      [BitConverter]::ToSingle($bytes, 0)
    ), [BitConverter]::ToSingle($bytes, 4)
    $this.double = '{0:G6}' -f [BitConverter]::Int64BitsToDouble($v)
  }
}
