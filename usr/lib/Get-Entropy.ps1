Set-Alias -Name ent -Value Get-Entropy
function Get-Entropy {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [Byte[]]$Bytes
  )

  end {
    $x = New-ILMethod -Noun $MyInvocation.MyCommand.Noun -Variables {
      Int32  $i
      Int32* $rng
      Int32* $pi
      Double $ent
      Double $src
    } -ReturnType ([Double]) -Parameters ([Byte[]]) -Code @'
      ldc_i4, 0x100
      conv_u
      ldc_i4_4
      mul_ovf_un
      localloc
      stloc_1
      ldloc_1
      ldc_i4, 0x400
      conv_i
      add
      stloc_2
      ldc_r8, 0.0
      stloc_3
      ldarg_0
      ldlen
      conv_i4
      dup
      stloc_0
      conv_r8
      stloc_s, $src
      br_s, :L_0
      :L_1 # 0x28
      ldloc_1
      ldarg_0
      ldloc_0
      ldelem_u1
      conv_i
      ldc_i4_4
      mul
      add
      dup
      ldind_i4
      ldc_i4_1
      add
      stind_i4
      :L_0 # 0x35
      ldloc_0
      ldc_i4_1
      sub
      dup
      stloc_0
      ldc_i4_0
      bge_s, :L_1
      br_s, :L_2
      :L_3 # 0x3f
      ldloc_2
      ldind_i4
      ldc_i4_0
      ble_s, :L_2
      ldloc_3
      ldloc_2
      ldind_i4
      conv_r8
      ldloc_2
      ldind_i4
      conv_r8
      ldloc_s, $src
      div
      ldc_r8, 2.
      call, [Math].GetMethod('Log', [Type[]]([Double], [Double]))
      mul
      add
      stloc_3
      :L_2 # 0x5f
      ldloc_2
      ldc_i4_4
      conv_i
      sub
      dup
      stloc_2
      ldloc_1
      bge_un_s, :L_3
      ldloc_3
      neg
      ldloc_s, $src
      div
      ret
'@
    $x.Invoke($Bytes)
  }
}

Export-ModuleMember -Alias ent -Function Get-Entropy
