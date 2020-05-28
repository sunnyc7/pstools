@{
  RootModule = 'pstools.psm1'
  ModuleVersion = '7.0.0.0'
  CompatiblePSEditions = 'Core'
  GUID = 'de1b363a-38a0-4921-837f-926c9fad2603'
  Author = 'greg zakharov'
  Copyright = 'MIT'
  Description = 'Useful utilities for Win10 in everyday experience.'
  PowerShellVersion = '7.0'
  AliasesToExport = @(
    'clockres',
    'clpws',
    'ent',
    'handle',
    'pipelist',
    'psdump',
    'psresume',
    'psuspend',
    'vadump'
  )
  FunctionsToExport = @(
    'Clear-PsWorkingSet',
    'Get-ApiSet',
    'Get-ClockRes',
    'Get-CpuCache',
    'Get-CredProviders',
    'Get-Entropy',
    'Get-PipeList',
    'Get-PsDump',
    'Get-PsHandle',
    'Get-PsVMInfo',
    'Resume-PsProcess',
    'Suspend-PsProcess'
  )
  FileList = @(
    'lib\accel.ps1',
    'lib\dynamic.ps1',
    'lib\pcall.ps1',
    'lib\types.ps1',
    'lib\utils.ps1',
    'usr\lib\Clear-PsWorkingSet.ps1',
    'usr\lib\Get-ApiSet.ps1',
    'usr\lib\Get-ClockRes.ps1',
    'usr\lib\Get-CpuCache.ps1',
    'usr\lib\Get-CredProviders.ps1',
    'usr\lib\Get-Entropy.ps1',
    'usr\lib\Get-PipeList.ps1',
    'usr\lib\Get-PsDump.ps1',
    'usr\lib\Get-PsHandle.ps1',
    'usr\lib\Get-PsVMInfo.ps1',
    'usr\lib\Resume-PsProcess.ps1',
    'usr\lib\Suspend-PsProcess.ps1',
    'pstools.psd1',
    'pstools.psm1'
  )
}
