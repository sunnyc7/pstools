function Out-Notepad {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [AllowEmptyString()]
    [String[]]$Text
  )

  begin {
    New-Delegate user32 {
      ptr FindWindowExW([ptr, ptr, buf, buf])
      int SendMessageW([ptr, uint, ptr, buf])
    }
  }
#  process {}
  end {
    $notepad = Start-Process notepad -PassThru
    [void]$notepad.WaitForInputIdle()
    [void]$user32.SendMessageW.Invoke(
       $user32.FindWindowExW.Invoke(
         $notepad.MainWindowHandle, [IntPtr]::Zero, [buf].Uni('Edit'), $null
       ), 0xC, 0, [buf].Uni((
         ($Text, $input)[[Int32]$MyInvocation.ExpectingInput] -join "`n"
       ))
    )
    $notepad.Dispose()
  }
}
