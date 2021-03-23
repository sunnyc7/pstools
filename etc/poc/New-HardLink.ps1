function New-HardLink {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({!!($script:src = Get-Item $_ -ErrorAction 0)})]
    [String]$Source,

    [Parameter(Mandatory, Position=1)]
    [ValidateNotNullOrEmpty()]
    [String]$Target
  )

  end {
    if ($src.PSIsContainer) {
      Write-Verbose 'operation cannot be applied to folders.'
      return $false
    }

    New-Delegate kernel32 {
      bool CreateHardLinkW([buf, buf, ptr])
    }

    $kernel32.CreateHardLinkW.Invoke(
      [buf].Uni($Target), [buf].Uni($src.FullName), [IntPtr]::Zero
    )
  }
}

Export-ModuleMember -Function New-HardLink
