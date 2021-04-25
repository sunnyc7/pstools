using namespace System.Reflection.Emit
using namespace System.Runtime.InteropServices

$GetDllExports = {
  param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][String]$Module)

  end {
    $mod = ($ps = Get-Process -Id $PID).Modules.Where{$_.ModuleName -match "^$Module"}.BaseAddress
    $ps.Dispose() && $($jmp = ($mov = [Marshal]::ReadInt32($mod, 0x3C)) + [Marshal]::SizeOf([UInt32]0))
    $jmp = switch ([BitConverter]::ToUInt16([BitConverter]::GetBytes([Marshal]::ReadInt16($mod, $jmp)), 0)) {
      0x014C { 0x20, 0x78, 0x7C } 0x8664 { 0x40, 0x88, 0x8C } default { throw [SystemException]::new() }
    }
    $tmp, $fun = $mod."ToInt$($jmp[0])"(), @{}
    $va, $sz = [Marshal]::ReadInt32($mod, $mov + $jmp[1]), [Marshal]::ReadInt32($mod, $mov + $jmp[2])
    ($ed = @{bs = 0x10; nf = 0x14; nn = 0x18; af = 0x1C; an = 0x20; ao = 0x24}).Keys.ForEach{
      $val = [Marshal]::ReadInt32($mod, $va + $ed.$_)
      Set-Variable -Name $_ -Value ($_.StartsWith('a') ? $tmp + $val : $val) -Scope Script
    }
    function Assert-Forwarder([UInt32]$fa) { end { ($va -le $fa) -and ($fa -lt ($va + $sz)) } }
    (0..($nf - 1)).ForEach{
      $fun[$bs + $_] = (Assert-Forwarder ($fa = [Marshal]::ReadInt32([IntPtr]($af + $_ * 4)))) ? @{
        Address = ''; Forward = [Marshal]::PtrToStringAnsi([IntPtr]($tmp + $fa))
      } : @{Address = [IntPtr]($tmp + $fa); Forward = ''}
    }
    (0..($nn - 1)).ForEach{
      [PSCustomObject]@{
        Ordinal = ($ord = $bs + [Marshal]::ReadInt16([IntPtr]($ao + $_ * 2)))
        Address = $fun[$ord].Address
        Name = [Marshal]::PtrToStringAnsi([IntPtr]($tmp + [Marshal]::ReadInt32([IntPtr]($an + $_ * 4))))
        Forward = $fun[$ord].Forward
      }
    }
  }
}

function ConvertFrom-PtrToMethod {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateScript({$_ -ne [IntPtr]::Zero})]
    [IntPtr]$Address,

    [Parameter(Mandatory, Position=1)]
    [ValidateNotNull()]
    [Type]$Prototype,

    [Parameter(Position=2)]
    [ValidateNotNullOrEmpty()]
    [CallingConvention]$CallingConvention = 'Cdecl'
  )

  end {
    $method = $Prototype.GetMethod('Invoke')
    $returntype, $paramtypes = $method.ReturnType, $method.GetParameters().ParameterType
    $paramtypes = $paramtypes ?? $null # requires an explicit null
    $il, $sz = ($holder = [DynamicMethod]::new(
      'Invoke', $returntype, $paramtypes, $Prototype
    )).GetILGenerator(), [IntPtr]::Size

    if ($paramtypes) {
      (0..($paramtypes.Length - 1)).ForEach{$il.Emit([OpCodes]::ldarg, $_)}
    }

    $il.Emit([OpCodes]::"ldc_i$sz", $Address."ToInt$($sz * 8)"())
    $il.EmitCalli([OpCodes]::calli, $CallingConvention, $returntype, $paramtypes)
    $il.Emit([OpCodes]::ret)

    $holder.CreateDelegate($Prototype)
  }
}

$ExportCache = {
  param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][String]$Module)

  end {
    if (!($exp = $ExecutionContext.SessionState.PSVariable.Get("__$Module").Value)) {
      Set-Variable -Name "__$Module" -Value (
        $exp = $GetDllExports.Invoke($Module)
      ) -Option Constant -Scope Global -Visibility Private
      $exp
    }
    else {$exp}
  }
}

$Signatures = @{
  RtlNtStatusToDosError = [Func[Int32, Int32]]
}

$ExportCache.Invoke('ntdll').Where{$_.Name -in $Signatures.Keys}.ForEach{
  Set-Variable -Scope Global -Option ReadOnly -Name $_.Name -Value (
    ConvertFrom-PtrToMethod $_.Address $Signatures[$_.Name] StdCall
  ) -Force
}

$Signatures = @{
  FreeLibrary = [Func[IntPtr, Boolean]]
  GetModuleHandleW = [Func[[Byte[]], IntPtr]]
  GetProcAddress = [Func[IntPtr, String, IntPtr]]
  LoadLibraryW = [Func[[Byte[]], IntPtr]]
}

$ExportCache.Invoke('kernelbase').Where{$_.Name -in $Signatures.Keys}.ForEach{
  Set-Variable -Scope Global -Option ReadOnly -Name (
    $_.Name.EndsWith('W') ? $_.Name.Substring(0, $_.Name.Length - 1) : $_.Name
  ) -Value (ConvertFrom-PtrToMethod $_.Address $Signatures[$_.Name] StdCall) -Force
}

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
  ('FreeLibrary',
   'GetModuleHandle',
   'GetProcAddress',
   'LoadLibrary',
   'RtlNtStatusToDosError'
  ).ForEach{ Remove-Variable -Name $_ -Scope Global -Force }
}

('lib', 'usr').ForEach{
  (Get-ChildItem -Path "$PSScriptRoot\$_" -Filter *.ps1).ForEach{.$_.FullName}
}
