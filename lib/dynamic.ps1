using namespace System.Reflection
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
