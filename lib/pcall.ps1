using namespace System.Linq
using namespace System.Reflection
using namespace System.Reflection.Emit
using namespace System.Linq.Expressions
using namespace System.Runtime.InteropServices

function New-Delegate {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$Module,

    [Parameter(Mandatory, Position=1)]
    [ValidateScript({![String]::IsNullOrEmpty($_)})]
    [ScriptBlock]$Signature,

    [Parameter()]
    [Switch]$LVal
  )

  begin {
    if (!($stash = $ExecutionContext.SessionState.PSVariable.Get('PwsHandlesStash'))) {
      $stash = Set-Variable -Name PwsHandlesStash -Value (
        [IntPtr[]]@()
      ) -Visibility Private -Scope Global -PassThru
    }

    $kernel32 = @{}
    [Array]::Find(( # GetModuleHandle, GetProcAddress and LoadLibrary
      Add-Type -AssemblyName Microsoft.Win32.SystemEvents -PassThru
    ), [Predicate[Type]]{$args[0].Name -eq 'kernel32'}).GetMethods(
      [BindingFlags]'NonPublic, Static, Public'
    ).Where{$_.Name -cmatch '\A(Get|Load)(P|M|L)'}.ForEach{$kernel32[$_.Name] = $_}

    if (($mod = $kernel32.GetModuleHandle.Invoke($null, @($Module))) -eq [IntPtr]::Zero) {
      if (($mod = $kernel32.LoadLibrary.Invoke($null,@($Module))) -eq [IntPtr]::Zero) {
        throw [DllNotfoundException]::new("Cannot find $Module library.")
      }
      $stash.Value += $mod
    }
  }
  process {}
  end {
    $funcs = @{}
    for ($i, $m, $fn, $p = 0, ([Expression].Assembly.GetType(
        'System.Linq.Expressions.Compiler.DelegateHelpers'
      ).GetMethod('MakeNewCustomDelegate', [BindingFlags]'NonPublic, Static')
      ), [Marshal].GetMethod('GetDelegateForFunctionPointer', ([IntPtr])),
      $Signature.Ast.FindAll({$args[0].CommandElements}, $true).ToArray();
      $i -lt $p.Length; $i++
    ) {
      $fnret, $fname = ($def = $p[$i].CommandElements).Value

      if (($fnsig = $kernel32.GetProcAddress.Invoke($null, @($mod, $fname))) -eq [IntPtr]::Zero) {
        throw [InvalidOperationException]::new("Cannot find $fname signature.")
      }

      $fnargs = $def.Pipeline.Extent.Text
      [Object[]]$fnargs = [String]::IsNullOrEmpty($fnargs) ? $fnret : (
        ($fnargs -replace '\[|\]' -split ',\s+?').ForEach{
          $_.StartsWith('$') ? (Get-Variable $_.Remove(0, 1) -ValueOnly) : $_
        } + $fnret
      )

      $funcs[$fname] = $fn.MakeGenericMethod(
        [Delegate]::CreateDelegate([Func[[Type[]], Type]], $m).Invoke($fnargs)
      ).Invoke([Marshal], $fnsig)
    }

    if ($LVal) { return $funcs } # do not establish variable automatically

    Add-Member -InputObject $funcs -Name Dispose -MemberType ScriptMethod -Value {
      if (!($stash = $ExecutionContext.SessionState.PSVariable.Get('PwsHandlesStash')).Value) {
        return # nothing to release
      }

      $kernel32 = New-Delegate -Module kernel32 -Signature { Boolean FreeLibrary([IntPtr]) } -LVal
      [ParallelEnumerable]::Reverse([ParallelEnumerable]::AsParallel($stash.Value)).ForEach{
        if (!([Boolean]$res = $kernel32.FreeLibrary.Invoke($_))) { Write-Warning $res }
      }
      $stash.Value = [IntPtr[]]@()
    }

    Set-Variable -Name $Module -Value $funcs -Scope Script -Force
  }
}

function New-ILMethod {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$Noun,

    [Parameter(Mandatory, Position=1)]
    [ValidateNotNullOrEmpty()]
    [String]$Code,

    [Parameter()][Type]$ReturnType = [void],
    [Parameter()][Type[]]$Parameters = @(),
    [Parameter()][ScriptBlock]$Variables
  )

  end {
    $il = ($dm = [DynamicMethod]::new($Noun, $ReturnType, $Parameters)).GetILGenerator()
    if ($Variables) {
      $Variables.Ast.FindAll({$args[0].CommandElements}, $true).ToArray().ForEach{
        Set-Variable -Name $($_.CommandElements.VariablePath.UserPath) -Value $il.DeclareLocal(
          [Type]::GetType("System.$($_.CommandElements.Value)")
        )
      }
    }

    if (($lnum = ($Code.Split("`n") | Select-String -Pattern '^(\s+)?:').Length)) {
      $labels = (0..($lnum - 1)).ForEach{
        $Code = $Code -replace ":L_$_.*", "`$labels[$_]"
        $il.DefineLabel()
      }
    }

    [ScriptBlock]::Create((Out-String -InputObject ($Code.Split("`n").Trim().ForEach{
      '$il.' + $($_.StartsWith('$') ? "MarkLabel($_)" : "Emit([OpCodes]::$_)")
    }))).Invoke()
    $fnarg, $fnret = ($Parameters.Name.ForEach{"[$_]"} -join ', '), "[$($ReturnType.Name)]"
    $dm.CreateDelegate([void] -eq $ReturnType ? "Action[$fnarg]" : "Func[$(
        $fnarg ? $fnarg + ', ' + $fnret : $fnret
      )]"
    )
  }
}
