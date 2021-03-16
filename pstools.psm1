('lib', 'usr\lib').ForEach{
  (Get-ChildItem -Path "$PSScriptRoot\$_" -Filter *.ps1).ForEach{.$_.FullName}
}
