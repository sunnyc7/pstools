function Get-CpuBrand {
  [CmdletBinding()]param()

  end {
    New-Delegate ntdll {
      int NtQuerySystemInformation([uint, buf, uint, uint_])
    }

    $req = 0
    if (($nts = $ntdll.NtQuerySystemInformation.Invoke(
      105, $null, 0, [ref]$req
    )) -ne 0xC0000004) {
      Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
      return
    }

    $buf = [Byte[]]::new($req)
    if (($nts = $ntdll.NtQuerySystemInformation.Invoke(
      105, $buf, $buf.Length, [ref]$req
    )) -ne 0) {
      Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
      return
    }

    [Text.Encoding]::ASCII.GetString($buf)
  }
}
