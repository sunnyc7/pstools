@{
  RootModule = 'pstools.psm1'
  ModuleVersion = '7.0.1.5'
  CompatiblePSEditions = 'Core'
  GUID = 'de1b363a-38a0-4921-837f-926c9fad2603'
  Author = 'greg zakharov'
  Copyright = 'MIT'
  Description = 'Useful utilities for Win10 in everyday experience.'
  PowerShellVersion = '7.1'
  AliasesToExport = @(
    'clockres',
    'clpws',
    'coreinfo',
    'ent',
    'handle',
    'loadord',
    'lsess',
    'pipelist',
    'psdump',
    'psresume',
    'psuspend',
    'streams',
    'strings',
    'time',
    'vadump',
    'whois'
  )
  FunctionsToExport = @(
    'Clear-AppCompatCache',
    'Clear-PsWorkingSet',
    'Get-ApiSet',
    'Get-ClockRes',
    'Get-CpuCache',
    'Get-CpuId',
    'Get-CredProviders',
    'Get-Entropy',
    'Get-LoadOrder',
    'Get-LogonSessions',
    'Get-PipeList',
    'Get-PsDump',
    'Get-PsHandle',
    'Get-PsVMInfo',
    'Get-Streams',
    'Get-Strings',
    'Measure-Execution',
    'Resume-PsProcess',
    'Show-WhoIs',
    'Suspend-PsProcess'
  )
  FileList = @(
    'etc\formats.ps1',
    'lib\accel.ps1',
    'lib\dynamic.ps1',
    'lib\pcall.ps1',
    'lib\types.ps1',
    'lib\utils.ps1',
    'usr\lib\Clear-AppCompatCache.ps1',
    'usr\lib\Clear-PsWorkingSet.ps1',
    'usr\lib\Get-ApiSet.ps1',
    'usr\lib\Get-ClockRes.ps1',
    'usr\lib\Get-CpuCache.ps1',
    'usr\lib\Get-CpuId.ps1',
    'usr\lib\Get-CredProviders.ps1',
    'usr\lib\Get-Entropy.ps1',
    'usr\lib\Get-LoadOrder.ps1',
    'usr\lib\Get-LogonSessions.ps1',
    'usr\lib\Get-PipeList.ps1',
    'usr\lib\Get-PsDump.ps1',
    'usr\lib\Get-PsHandle.ps1',
    'usr\lib\Get-PsVMInfo.ps1',
    'usr\lib\Get-Streams.ps1',
    'usr\lib\Get-Strings.ps1',
    'usr\lib\Measure-Execution.ps1',
    'usr\lib\Resume-PsProcess.ps1',
    'usr\lib\Show-WhoIs.ps1',
    'usr\lib\Suspend-PsProcess.ps1',
    'pstools.psd1',
    'pstools.psm1'
  )
  ScriptsToProcess = 'etc\formats.ps1'
}
