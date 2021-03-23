function Get-PowerStatus {
  [CmdletBinding()]param()

  end {
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.PowerStatus].GetConstructor(
      [Reflection.BindingFlags]'Instance, NonPublic',
      $null, [Type[]]@(), $null
    ).Invoke($null)
  }
}
