using namespace System.IO
using namespace System.Text

function Get-PeManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({!!($script:file = Convert-Path -Path $_ -ErrorAction 0)})]
    [ValidateNotNullOrEmpty()]
    [String]$Path
  )

  begin {
    $Path = $file
    function private:Convert-RvaToRaw([UInt32]$rva, [UInt32]$align) {
      end {
        [ScriptBlock]$Aligner = {
          param([UInt32]$size)
          ($size -band ($align - 1)) ? (($size -band ($align * -1)) + $align) : $size
        }

        $sections.ForEach{
          if (($rva -ge $_.VirtualAddress) -and (
            $rva -lt ($_.VirtualAddress + (& $Aligner $_.VirtualSize))
          )) { return ($rva - ($_.VirtualAddress - $_.PointerToRawData)) }
        }
      }
    }
  }
  #process {}
  end {
    try {
      $br = [BinaryReader]::new(($fs = [File]::OpenRead($Path)))
      if ($br.ReadUInt16() -ne 0x5A4D) {
        throw [InvalidOperationException]::new('DOS signature has not been found.')
      }
      $fs.Position = 0x3C # e_lfanew
      $fs.Position = $br.ReadUInt32() # move to IMAGE_NT_HEADERS
      if ($br.ReadUInt32() -ne 0x4550) {
        throw [InvalidOperationException]::new('PE signature has not been found.')
      }
      $fs.Position += 0x02 # IMAGE_FILE_HEADER->Machine
      $NumberOfSections = $br.ReadUInt16()
      $fs.Position += 0x0C # IMAGE_FILE_HEADER->... till SizeOfOptionalHeader
      $SizeOfOptionalHeader, $offset = $br.ReadUInt16(), ($fs.Position + 0x02)
      $fs.Position += 0x26 # getting FileAlignment
      $FileAlignment = $br.ReadUInt32()
      $fs.Position = $offset + $SizeOfOptionalHeader
      if (!($PointerToRawData = ($sections = (1..$NumberOfSections).ForEach{
        [PSCustomObject]@{
          Name = [String]::new($br.ReadChars(0x08)).Trim("`0")
          VirtualSize = $br.ReadUInt32()
          VirtualAddress = $br.ReadUInt32()
          SizeOfRawData = $br.ReadUInt32()
          PointerToRawData = $br.ReadUInt32()
        }
        $fs.Position += 0x10 # move to the next section
      }).Where{$_.Name -eq '.rsrc'}.PointerToRawData)) {
        throw [InvalidOperationException]::new('It seems there are no resources.')
      }
      $fs.Position = $PointerToRawData + 0x0C # enumerate resources
      $entry = {
        param([UInt16]$name, [UInt16]$id)
        end {
          (1..($name + $id)).ForEach{
            [PSCustomObject]@{
              Name = $br.ReadUInt32()
              OffsetToData = $br.ReadUInt32()
            }
          }
        }
      }
      if (!($manifest = (& $entry $br.ReadUInt16() $br.ReadUInt16()
        ).Where{$_.Name -eq 24}.OffsetToData)) {
        throw [InvalidOperationException]::new('It seems there is no manifest.')
      }
      $fs.Position = $PointerToRawData + ($manifest -band 0x7FFFFFFF) + 0x0C # manifest directory
      $fs.Position = $PointerToRawData + (
        (& $entry ($n=$br.ReadUInt16()) ($i=$br.ReadUInt16())).OffsetToData -band 0x7FFFFFFF
      ) + 0x14 # LANGID
      "ResDir (MANIFEST) Entries:$($n+$i) (Named:$n, ID:$i)"
      $fs.Position = $PointerToRawData + $br.ReadUInt32() # IMAGE_RESOURCE_DATA_ENTRY
      $rva, $size = $br.ReadUInt32(), $br.ReadUInt32()
      "$(,([Char]32)*2)DataRVA: $($rva.ToString('X8')) DataSize: $($size.ToString('X'))`n"
      $fs.Position = Convert-RvaToRaw $rva $FileAlignment
      [Encoding]::UTF8.GetString($br.ReadBytes($size))
    }
    catch { Write-Verbose $_ }
    finally {
      ($br, $fs).ForEach{ if ($_) { $_.Dispose() } }
    }
  }
}

Export-ModuleMember -Function Get-PeManifest
