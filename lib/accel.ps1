$GetMyAssembly = {
  [AppDomain]::CurrentDomain.GetAssemblies().Where{
    !$_.Location -and $_.GetType('fmt')
  }
}

if (!($asm = & $GetMyAssembly)) {
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
      } catch { 'n/a' }
      $this.float = 'low {0:G6} high {1:G6}' -f (
        [BitConverter]::ToSingle($bytes, 0)
      ), [BitConverter]::ToSingle($bytes, 4)
      $this.double = '{0:G6}' -f [BitConverter]::Int64BitsToDouble($v)
    }
  }

  $asm = & $GetMyAssembly
}

($keys, $types = ($x = [PSObject].Assembly.GetType(
  'System.Management.Automation.TypeAccelerators'
))::Get.Keys, @{
  buf   = [Byte[]]
  dptr  = [UIntPtr]
  fmt   = $asm.GetType('fmt')
  ptr   = [IntPtr]
  ptr_  = [IntPtr].MakeByRefType()
  uint_ = [UInt32].MakeByRefType()
  sfh   = [Microsoft.Win32.SafeHandles.SafeFileHandle]
})[1].Keys.ForEach{$_ -notin $keys ? $x::Add($_, $types.$_) : $null}

($scheme = @{
  StrA = {param([Byte[]]$buf) [Text.Encoding]::Ascii.GetString($buf)}
  StrU = {param([Byte[]]$buf) [Text.Encoding]::Unicode.GetString($buf)}
  Ansi = {param([String]$str) [Text.Encoding]::Ascii.GetBytes($str)}
  Uni  = {param([String]$str) [Text.Encoding]::Unicode.GetBytes($str)}
}).Keys.ForEach{
  Add-Member -InputObject ([buf]) -Name $_ -MemberType ScriptMethod -Value $scheme[$_] -Force
}
