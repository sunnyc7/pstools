function Clear-AppCompatCache {
  [CmdletBinding()]param()

  end {
    (Test-IsAdmin) ? $(
      New-Delegate kernel32 {
        bool BaseFlushAppcompatCache
      }

      $kernel32.BaseFlushAppcompatCache.Invoke()
    ) : (Write-Warning 'pwsh should be elevated')
  }
}

Export-ModuleMember -Function Clear-AppCompatCache
