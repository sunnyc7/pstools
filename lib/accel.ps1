($keys, $types = ($x = [PSObject].Assembly.GetType(
  'System.Management.Automation.TypeAccelerators'
))::Get.Keys, @{
  buf   = [Byte[]]
  dptr  = [UIntPtr]
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
