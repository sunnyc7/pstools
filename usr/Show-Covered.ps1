function Show-Covered {
  [CmdletBinding()]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Accelerators', 'DynamicTypes', 'ExpressionAst')]
    [Alias('dt')]
    [String]$DataType = 'DynamicTypes'
  )

  end {
    switch ($DataType) {
      'Accelerators' {
        [PSObject].Assembly.GetType(
          'System.Management.Automation.TypeAccelerators'
        )::Get -as [Collections.Generic.SortedDictionary[String, Type]]
      }
      'DynamicTypes' {
        [PSCustomObject]@{IsPublic=$null;IsSerial=$null;Name=$null;BaseType=$null}
        [AppDomain]::CurrentDomain.GetAssemblies().Where{!$_.Location}.ForEach{
          "`e[7m$_.FullName`e[0m" # header of each subtable
          ($_.DefinedTypes ? $_.DefinedTypes : $_.GetType()) |
          Select-Object -Property IsPublic, @{
            Name = 'IsSerial'; Expression = {$_.IsSerializable}
          }, Name, BaseType
        }
      }
      'ExpressionAst' {
        [PSObject].Assembly.GetTypes().Where{$_.Name -cmatch '.+Ast$'} |
        Select-Object -Property IsPublic, @{
          Name = 'IsSerial'; Expression = {$_.IsSerializable}
        }, @{Name = 'Name'; Expression = {($name = $_.Name -replace 'ast$'
        ) -eq 'expression' ? $name : ($name -replace 'expression')}}, BaseType |
        Sort-Object -Property Name -Unique
      }
    } # switch
  }
}

Export-ModuleMember -Function Show-Covered
