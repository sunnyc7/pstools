using namespace System.Reflection
using namespace System.ComponentModel

function Get-LoggedOn {
  [CmdletBinding()]param()

  end {
    $rk, $ft = (Get-Item 'HKCU:\Volatile Environment'), [Int32[]]::new(2)
    if (!($res = $rk.GetType().Assembly.GetType('Interop+Advapi32').GetMethod(
      'RegQueryInfoKey', [BindingFlags]'NonPublic, Static'
    ).Invoke(
      $null, @($rk.Handle, $null, $null, [IntPtr]::Zero,
      $null, $null, $null, $null, $null, $null, $null, $ft
    )))) {
      [DateTime]::FromFileTime(
        ([Int64]$ft[1] -shl 32) -bor [BitConverter]::ToUInt32(
          [BitConverter]::GetBytes($ft[0]), 0
        )
      )
    }
    else {Write-Verbose ([Win32Exception]::new($res).Message)}
    $rk.Dispose()
  }
}
