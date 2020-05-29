using namespace System.ComponentModel
using namespace System.Security.Principal

function ConvertTo-ErrMessage {
  [CmdletBinding(DefaultParameterSetName='WinNt')]
  param(
    [Parameter(Mandatory, ParameterSetName='WinNt', Position=0)]
    [Int32]$WinNt,

    [Parameter(Mandatory, ParameterSetName='NtStatus', Position=0)]
    [Int32]$NtStatus
  )

  end {
    [Win32Exception]::new(
      $WinNt ? $WinNt : $(
        New-Delegate ntdll { int RtlNtStatusToDosError([int]) }
        $ntdll.RtlNtStatusToDosError.Invoke($NtStatus)
      )
    ).Message
  }
}

function New-PsProxy {
  [CmdletBinding(DefaultParameterSetName='Name')]
  param(
    [Parameter(Mandatory, ParameterSetName='Name', Position=0)]
    [ValidateNotNullOrEmpty()]
    [String[]]$Name,

    [Parameter(Mandatory, ParameterSetName='Id', Position=0)]
    [Alias('PID')]
    [Int32[]]$Id,

    [Parameter(Mandatory, Position=1)]
    [ValidateScript({![String]::IsNullOrEmpty($_)})]
    [ScriptBlock]$Callback
  )

  begin {
    if ($PSBoundParameters.Callback) {
      [void]$PSBoundParameters.Remove('Callback')
    }
    $PSBoundParameters.Add('OutVariable', 'ps')

    $cmd = {Out-Null -InputObject (&(
      Get-Command -CommandType Cmdlet -Name Get-Process
    ) @PSBoundParameters)}.GetSteppablePipeline($MyInvocation.CommandOrigin)
    $cmd.Begin($PSCmdlet)
  }
  process { $cmd.Process($_) }
  end {
    $cmd.End()
    $ps.ForEach{
      .$Callback $_
      $_.Dispose()
    }
  }
}

function Test-IsAdmin {
  end {
    [WindowsPrincipal]::new(
      [WindowsIdentity]::GetCurrent()
    ).IsInRole([WindowsBuiltInRole]::Administrator)
  }
}
