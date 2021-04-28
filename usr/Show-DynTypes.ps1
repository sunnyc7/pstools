function Show-DynTypes {
  [CmdletBinding()]param()

  end {
    [PSCustomObject]@{IsPublic=$null;IsSerial=$null;Name=$null;BaseType=$null}
    [AppDomain]::CurrentDomain.GetAssemblies().Where{!$_.Location}.ForEach{
      "`e[7m$_.FullName`e[0m" # header of each subtable
      ($_.DefinedTypes ? $_.DefinedTypes : $_.GetType()) |
      Select-Object -Property IsPublic, @{
        N='IsSerial';E={$_.IsSerializable}
      }, Name, BaseType
    }
  }
}

Export-ModuleMember -Function Show-DynTypes
