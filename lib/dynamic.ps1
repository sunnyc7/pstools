using namespace System.Reflection
using namespace System.Reflection.Emit
using namespace System.Management.Automation
using namespace System.Collections.ObjectModel
using namespace System.Runtime.InteropServices

function Get-DynBuilder {
  end {
    if (!($pmb = $ExecutionContext.SessionState.PSVariable.Get('PwshDynBuilder').Value)) {
      Set-Variable -Name PwshDynBuilder -Value ($pmb =
        ([AssemblyBuilder]::DefineDynamicAssembly(
          ([AssemblyName]::new('PwshDynBuilder')), 'Run'
        )).DefineDynamicModule('PwshDynBuilder', $false)
      ) -Option Constant -Scope Global -Visibility Private
      $pmb
    }
    else {$pmb}
  }
}

function New-DynParameter {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [Hashtable[]]$Parameter
  )

  end {
    $dict = [RuntimeDefinedParameterDictionary]::new()

    $Parameter.ForEach{
      if ($_.GetType().Name -ne 'Hashtable' -or !$_.Count) {
        throw [ArgumentException]::new('Invalid argument.')
      }

      $attr = [Collection[Attribute]]::new()
      $attr.Add((New-Object Management.Automation.ParameterAttribute -Property @{
        ParameterSetName = $_.ParameterSetName # __AllParameterSets by default
        Mandatory = $_.Mandatory
        Position = $_.Position -ge 0 ? $_.Position : 0x80000000
        ValueFromPipeline = $_.ValueFromPipeline
        ValueFromPipelineByPropertyName = $_.ValueFromPipelineByPropertyName
      }))

      if ($_.ValidateNotNullOrEmpty) {
        $attr.Add([ValidateNotNullOrEmptyAttribute]::new())
      }

      if ($_.ValidateScript) {
        $attr.Add((New-Object Management.Automation.ValidateScriptAttribute($_.ValidateScript)))
      }

      if ($_.ValidateSet) {
        $attr.Add((New-Object Management.Automation.ValidateSetAttribute($_.ValidateSet)))
      }

      $dict.Add($_.Name, (New-Object Management.Automation.RuntimeDefinedParameter(
        $_.Name, $_.Type, $attr) -Property @{
          Value = $_.Value # this makes it easy to call dynamic parameters
        } -OutVariable "script:param$($_.Name)" # example: $param(Name)
      ))
    }

    $dict
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
