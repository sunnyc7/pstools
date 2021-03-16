Set-Alias -Name loadord -Value Get-LoadOrder
function Get-LoadOrder {
  [CmdletBinding()]param([Parameter()][Switch]$AsTable)

  begin {
    $root, $sysdir = 'HKLM:\SYSTEM\CurrentControlSet', [Environment]::SystemDirectory
    $type = 'Boot', 'System', 'Automatic' # launching types
    $group = (Get-ItemProperty "$root\Control\ServiceGroupOrder").List
    $items = ($rk = Get-Item "$root\Services").GetSubKeyNames().ForEach{
      if (($start = ($sub = $rk.OpenSubkey($_)).GetValue('Start')) -lt 3) {
        [PSCustomObject]@{
          Name = $_
          Group = $sub.GetValue('Group')
          Start = $start
          Tag   = $sub.GetValue('Tag')
          Image = $sub.GetValue('ImagePath') -replace '(?:\\)?.*system32', $sysdir
        }
      }
      $sub.Dispose()
    }
    $rk.Dispose()
    $order = @{} # approximate launch order
    ($rk = Get-Item "$root\Control\GroupOrderList").GetValueNames().ForEach{
      $order[$_] = @()
      $value = $rk.GetValue($_)
      for ($i = 0; $i -lt $value.Length; $i += 3) {
        $order[$_] += [BitConverter]::ToUInt16($value[$i..($i + 3)], 0)
        $i++
      }
      # remove tags counter
      $order[$_] = $order[$_][1..($order[$_].Length - 1)]
    }
    $rk.Dispose()

    function private:Get-Objects([String]$Value) {
      process {
        $scope = $items.Where{$_.Start -eq $type.IndexOf($Value)}
        $parts = $scope | Group-Object -Property Group
        $parts = foreach ($i in $(foreach ($g in $group) {
          $parts.Where{$_.Name -eq $g}
        })) {
          if ($i.Count -gt 1) {
            $cast = $i.Group.Where{$_.Tag}
            $($(foreach ($o in $order[$i.Name]) {
              $i.Group.Where{$_.Tag -eq $o}
            }), $cast.Where{
              $_.Tag -notin $order[$i.Name]
            }, $i.Group.Where{!$_.Tag}).ForEach{$_}
          }
          else { $i.Group }
        }
        $parts += $scope.Where{$_.Group -notin $group}
        foreach ($p in $parts) {
          [PSCustomObject]@{
            StartType = $Value
            Group = $p.Group
            Tag = $p.Tag
            ServiceOrDevice = $p.Name
            ImagePath = $p.Image
          }
        }
      }
    }
  }
  process {}
  end {
    $type = $type.ForEach{Get-Objects $_}
    $AsTable ? (Format-Table -InputObject $type -AutoSize) : $type
  }
}

Export-ModuleMember -Alias loadord -Function Get-LoadOrder
