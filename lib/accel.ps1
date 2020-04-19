$keys, $types = ($x = [PSObject].Assembly.GetType(
  'System.Management.Automation.TypeAccelerators'
))::Get.Keys, @{
  buf   = [Byte[]]
  dptr  = [UIntPtr]
  ptr   = [IntPtr]
  ptr_  = [IntPtr].MakeByRefType()
  uint_ = [UInt32].MakeByRefType()
  sfh   = [Microsoft.Win32.SafeHandles.SafeFileHandle]
}
$types.Keys.ForEach{if ($_ -notin $keys) {$x::Add($_, $types.$_)}}

Add-Member -InputObject ([buf]) -Name Uni -MemberType ScriptMethod -Value {
  param([String]$str) [Text.Encoding]::Unicode.GetBytes($str)
} -Force
