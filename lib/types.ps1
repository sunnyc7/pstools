using namespace System.Reflection
using namespace System.Reflection.Emit
using namespace System.Collections.Specialized
using namespace System.Runtime.InteropServices

function New-Enum {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$Name,

    [Parameter(Mandatory, Position=1)]
    [ValidateScript({![String]::IsNullOrEmpty($_)})]
    [ScriptBlock]$Definition,

    [Parameter()]
    [Type]$Type = [Int32],

    [Parameter()]
    [Switch]$Flags
  )

  end {
    if (!($pmb = Get-DynBuilder).GetType($Name)) {
      $pack = $Type -as [Type]
      $type = $pmb.DefineEnum($Name, 'Public', $pack)
      if ($Flags) {
        $type.SetCustomAttribute((
          [CustomAttributeBuilder]::new([FlagsAttribute].GetConstructor(@()), @())
        ))
      }

      $i = 0
      $Definition.ToString().Trim().Split("`r`n", [StringSplitOptions]::RemoveEmptyEntries).ForEach{
        $arr = @(($_ -split '(?:\s+)?=(?:\s+)?').Trim())
        [void]$type.DefineLiteral($arr[0], ($i = [Int32]($arr[1] ?? $i)) -as $pack)
        $i+=1
      }
      [void]$type.CreateType()
    }
  }
}

function New-Structure {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$Name,

    [Parameter(Mandatory, Position=1)]
    [ValidateScript({![String]::IsNullOrEmpty($_)})]
    [ScriptBlock]$Definition,

    [Parameter()]
    [ValidateSet(
      'Unspecified', 'Size1', 'Size2', 'Size4', 'Size8', 'Size16', 'Size32', 'Size64', 'Size128'
    )]
    [ValidateNotNullOrEmpty()]
    [PackingSize]$PackingSize = 'Unspecified',

    [Parameter()]
    [ValidateSet('Ansi', 'Auto', 'Unicode')]
    [ValidateNotNullOrEmpty()]
    [CharSet]$CharSet = 'Ansi',

    [Parameter()]
    [Switch]$Explicit
  )

  begin {
    [TypeAttributes]$attr = 'BeforeFieldInit, Class, Public, Sealed'
    $attr = $attr -bor ($Explicit.IsPresent ? 'Explicit' : 'Sequential') -bor "$($CharSet)Class"
  }
  process {}
  end {
    if (!($pmb = Get-DynBuilder).GetType($Name)) {
      $type = $pmb.DefineType($Name, $attr, [ValueType], $PackingSize)
      $ctor = [MarshalAsAttribute].GetConstructor(
        [BindingFlags]'Instance, Public', $null, [Type[]]([UnmanagedType]), $null
      )
      $sc = [MarshalAsAttribute].GetField('SizeConst')

      $Definition.Ast.FindAll({$args[0].CommandElements}, $true).ToArray().ForEach{
        $ftype, $fdesc = $_.CommandElements.Value
        $ftype = $pmb.GetType($ftype) ?? [Type]$ftype
        $fdesc = @(($fdesc -split '\s+?').Where{$_}) # field, param ...
        switch ($fdesc.Length) {
          1 {[void]$type.DefineField($fdesc[0], $ftype, 'Public')}
          2 {
            [void]($Explicit.IsPresent ? $type.DefineField($fdesc[0], $ftype, 'Public'
            ).SetOffset([Int32]$fdesc[1]) : $type.DefineField(
              $fdesc[0], $ftype, 'Public, HasFieldMarshal'
            ).SetCustomAttribute(
              [CustomAttributeBuilder]::new($ctor, [Object]([UnmanagedType]$fdesc[1]))
            ))
          }
          3 {
            [void]$type.DefineField($fdesc[0], $ftype, 'Public, HasFieldMarshal'
            ).SetCustomAttribute(
              [CustomAttributeBuilder]::new($ctor, [UnmanagedType]$fdesc[1], $sc, ([Int32]$fdesc[2]))
            )
          }
        }
      }
      $il = $type.DefineMethod('GetSize', 'Public, Static', [Int32], [Type[]]@()).GetILGenerator()
      $il.Emit([OpCodes]::ldtoken, $type)
      $il.Emit([OpCodes]::call, [Type].GetMethod('GetTypeFromHandle'))
      $il.Emit([OpCodes]::call, [Marshal].GetMethod('SizeOf', [Type[]]([Type])))
      $il.Emit([OpCodes]::ret)
      $il = $type.DefineMethod('OfsOf', 'Public, Static', [Int32], [Type[]]@([String])).GetILGenerator()
      $local = $il.DeclareLocal([String])
      $il.Emit([OpCodes]::ldtoken, $type)
      $il.Emit([OpCodes]::call, [Type].GetMethod('GetTypeFromHandle'))
      $il.Emit([OpCodes]::ldarg_0)
      $il.Emit([OpCodes]::call, [Marshal].GetMethod('OffsetOf', [Type[]]([Type], [String])))
      $il.Emit([OpCodes]::stloc_0)
      $il.Emit([OpCodes]::ldloca_s, $local)
      $il.Emit([OpCodes]::call, [IntPtr].GetMethod('ToInt32', [Type[]]@()))
      $il.Emit([OpCodes]::ret)
      $il = $type.DefineMethod(
        'op_Implicit', 'PrivateScope, Public, Static, HideBySig, SpecialName', $type, [Type]([IntPtr])
      ).GetILGenerator()
      $il.Emit([OpCodes]::ldarg_0)
      $il.Emit([OpCodes]::ldtoken, $type)
      $il.Emit([OpCodes]::call, [Type].GetMethod('GetTypeFromHandle'))
      $il.Emit([OpCodes]::call, [Marshal].GetMethod('PtrToStructure', [Type[]]([IntPtr], [Type])))
      $il.Emit([OpCodes]::unbox_any, $type)
      $il.Emit([OpCodes]::ret)
      [void]$type.CreateType()
    }
  }
}

function ConvertTo-BitMap {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateNotNullOrEmpty()]
    [Object]$Value,

    [Parameter(Mandatory, Position=1)]
    [ValidateScript({![String]::IsNullOrEmpty($_)})]
    [ScriptBlock]$BitMap
  )

  end {
    $vtor = [BitVector32]::new($Value)
    [PSCustomObject](ConvertFrom-StringData (
      ($BitMap.Ast.FindAll({$args[0].CommandElements}, $true).ToArray().ForEach{
        $fname, $fbits = $_.CommandElements[0, 2]
        $mov = !$mov ? [BitVector32]::CreateSection($fbits.Value)
                     : [BitVector32]::CreateSection($fbits.Value, $mov)
        '{0} = {1}' -f $fname.Value, $vtor[$mov]
			}) | Out-String)
		)
  }
}

function ConvertTo-PointerOrStructure {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateNotNullOrEmpty()]
    [Byte[]]$Buffer,

    [Parameter(Position=1)]
    [ValidateNotNull()]
    [Type]$Type
  )

  end {
    try {
      $gch = [GCHandle]::Alloc($Buffer, [GCHandleType]::Pinned)
      if ($Type) { $gch.AddrOfPinnedObject() -as $Type }
      else { $gch.AddrOfPinnedObject() }
    }
    catch { Write-Verbose $_ }
    finally {
      if ($gch) { $gch.Free() }
    }
  }
}
