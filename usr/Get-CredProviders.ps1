function Get-CredProviders {
  [CmdletBinding()]param()

  end {
    $root = 'HKLM:\SOFTWARE'
    ($clsids = Get-ChildItem ("$root\Microsoft\Windows\CurrentVersion" +
                               "\Authentication\Credential Providers")).ForEach{
      $clsid, $name = $_.PSChildName, $_.GetValue('')
      if (($prov = Get-ChildItem "$root\Classes\CLSID\$clsid" -ErrorAction 0)) {
        [PSCustomObject]@{
          CLSID = $clsid
          Name = $name
          Path = $prov.GetValue('')
        }
        $prov.Dispose()
      }
    }
    $clsids.Dispose()
  }
}

Export-ModuleMember -Function Get-CredProviders
