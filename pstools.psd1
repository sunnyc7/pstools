@{
  RootModule = 'pstools.psm1'
  ModuleVersion = '8.0.1.11'
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
    'pstree',
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
    'Find-Links',
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
    'Get-PsHandle',
    'Get-PsVMInfo',
    'Get-Streams',
    'Get-Strings',
    'Get-SysModules',
    'Measure-Execution',
    'Resume-PsProcess',
    'Show-Covered',
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
    'usr\Clear-AppCompatCache.ps1',
    'usr\Clear-PsWorkingSet.ps1',
    'usr\Find-Links.ps1',
    'usr\Get-ApiSet.ps1',
    'usr\Get-ClockRes.ps1',
    'usr\Get-CpuCache.ps1',
    'usr\Get-CpuId.ps1',
    'usr\Get-CredProviders.ps1',
    'usr\Get-Entropy.ps1',
    'usr\Get-LoadOrder.ps1',
    'usr\Get-LogonSessions.ps1',
    'usr\Get-PipeList.ps1',
    'usr\Get-PsDump.ps1',
    'usr\Get-PsHandle.ps1',
    'usr\Get-PsTree.ps1',
    'usr\Get-PsVMInfo.ps1',
    'usr\Get-Streams.ps1',
    'usr\Get-Strings.ps1',
    'usr\Get-SysModules.ps1',
    'usr\Measure-Execution.ps1',
    'usr\Resume-PsProcess.ps1',
    'usr\Show-Covered.ps1',
    'usr\Show-WhoIs.ps1',
    'usr\Suspend-PsProcess.ps1',
    'pstools.psd1',
    'pstools.psm1'
  )
  ScriptsToProcess = 'etc\formats.ps1'
}
