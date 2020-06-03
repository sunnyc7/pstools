Set-Alias -Name time -Value Measure-Execution
function Measure-Execution {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateScript({![String]::IsNullOrEmpty($_)})]
    [ScriptBlock[]]$ScriptBlock,

    [Parameter()]
    [ValidateRange(1, 3000)]
    [UInt16]$Count = 1,

    [Parameter()][Switch]$Pretty
  )

  end {
    for ($i = 0; $i -lt $ScriptBlock.Length; $i++) {
      [Console]::Write("`e[36;1mTesting block[$($i + 1)]`e[0m")
      $t = 0..$Count | Measure-Command -Expression $ScriptBlock[$i]
      $Pretty ? "`r`e[33;1mTotal tm`e[0m: $($t.ToString('G'))"
              : "`r`e[33;1mTotal ms`e[0m: $($t.TotalMilliseconds)"
    }
  }
}

Export-ModuleMember -Alias time -Function Measure-Execution
