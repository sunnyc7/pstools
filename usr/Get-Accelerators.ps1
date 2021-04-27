function Get-Accelerators {
  [CmdletBinding()]param()

  end {
    [PSObject].Assembly.GetType( # returns unsorted dictionary by default
      'System.Management.Automation.TypeAccelerators' # so...
    )::Get -as [Collections.Generic.SortedDictionary[String, Type]]
  }
}

Export-ModuleMember -Function Get-Accelerators
