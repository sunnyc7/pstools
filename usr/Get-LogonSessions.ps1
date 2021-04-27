using namespace System.Security.Principal

Set-Alias -Name lsess -Value Get-LogonSessions
function Get-LogonSessions {
  [CmdletBinding()]param([Parameter()][Switch]$AsTable)

  begin {
    New-Structure LUID {
      UInt32 LowPart
      Int32  HighPart
    } -CharSet Unicode

    New-Structure LSA_UNICODE_STRING {
      UInt16 Length
      UInt16 MaximumLength
      String 'Buffer LPWStr'
    } -CharSet Unicode

    New-Enum SECURITY_LOGON_TYPE {
      UndefinedLogonType = 0
      Interactive = 2
      Network
      Batch
      Service
      Proxy
      Unlock
      NetworkCleartext
      NewCredentials
      RemoteInteractive
      CachedInteractive
      CachedRemoteInteractive
      CachedUnlock
    } -Type ([UInt32])

    <#
    New-Structure LSA_LAST_INTER_LOGON_INFO {
      Int64  LastSuccessfulLogon
      Int64  LastFailedLogon
      UInt32 FailedAttemptCountSinceLastSuccessfulLogon
    } -CharSet Unicode
    #>

    New-Structure SECURITY_LOGON_SESSION_DATA {
      UInt32 Size
      LUID   LogonId
      LSA_UNICODE_STRING  UserName
      LSA_UNICODE_STRING  LogonDomain
      LSA_UNICODE_STRING  AuthenticationPackage
      SECURITY_LOGON_TYPE LogonType
      UInt32 Session
      IntPtr Sid
      Int64  LogonTime
      <#
      LSA_UNICODE_STRING  LogonServer
      LSA_UNICODE_STRING  DnsDomainName
      LSA_UNICODE_STRING  Upn
      UInt32 UserFlags
      LSA_LAST_INTER_LOGON_INFO LastLogonInfo
      LSA_UNICODE_STRING  LogonScript
      LSA_UNICODE_STRING  ProfilePath
      LSA_UNICODE_STRING  HomeDirectory
      LSA_UNICODE_STRING  HomeDirectoryDrive
      Int64  LogoffTime
      Int64  KickOffTime
      Int64  PasswordLastSet
      Int64  PasswordCanChange
      Int64  PasswordMustChange
      #>
    } -CharSet Unicode

    New-Delegate sspicli {
      int LsaEnumerateLogonSessions([uint_, ptr_])
      int LsaFreeReturnBuffer([ptr])
      int LsaGetLogonSessionData([ptr, ptr_])
    }

    $to_i = "ToInt$([IntPtr]::Size * 8)"
  }
  process {}
  end {
    $count, $slist, $dump = 0, [IntPtr]::Zero, @()
    try {
      if (($nts = $sspicli.LsaEnumerateLogonSessions.Invoke([ref]$count, [ref]$slist)) -ne 0) {
        throw (ConvertTo-ErrMessage -NtStatus $nts)
      }

      $luid, $data = $slist.$to_i(), [IntPtr]::Zero
      for ($i = 0; $i -lt $count; $i++) {
        if (($nts = $sspicli.LsaGetLogonSessionData.Invoke([IntPtr]$luid, [ref]$data)) -ne 0) {
          throw (ConvertTo-ErrMessage -NtStatus $nts)
        }

        $sess = $data -as [SECURITY_LOGON_SESSION_DATA]
        $dump += [PSCustomObject]@{
          LogonType   = $sess.LogonType
          UserName    = '{0}\{1}' -f $sess.LogonDomain.Buffer, $sess.UserName.Buffer
          AuthPackage = $sess.AuthenticationPackage.Buffer
          Session     = $sess.Session
          Sid         = $sess.Sid -ne [IntPtr]::Zero ?
                   [SecurityIdentifier]::new($sess.Sid).ToString() : [String]::Empty
          LogonTime   = [DateTime]::FromFileTime($sess.LogonTime)
        }
        $luid += [LUID]::GetSize()
        if (($nts = $sspicli.LsaFreeReturnBuffer.Invoke($data)) -ne 0) {
          Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
        }
      }
    }
    catch {Write-Verbose $_}
    finally {
      if ($slist -ne [IntPtr]::Zero) {
        if (($nts = $sspicli.LsaFreeReturnBuffer.Invoke($slist)) -ne 0) {
          Write-Verbose (ConvertTo-ErrMessage -NtStatus $nts)
        }
      }
    }

    if ($dump) { $AsTable ? (Format-Table -InputObject $dump -AutoSize) : $dump }
  }
}

Export-ModuleMember -Alias lsess -Function Get-LogonSessions
