Set-Alias -Name whois -Value Show-WhoIs
function Show-WhoIs {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [String]$Domain,

    [Parameter()][Switch]$UseAlternative
  )

  process {
    $params = @{
      Uri = "https://www.$($UseAlternative ? 'nic.ru/app/v1/get/whois'
                         : ('virustotal.com/vtapi/v2/domain/report?apikey=' +
        '4e3202fdbe953d628f650229af5b3eb49cd46b2d3bfe5546ae3c5fa48b554e0c&' +
        "domain=$Domain"
      ))"
      Method = $UseAlternative ? 'POST' : 'GET'
    }

    if ($UseAlternative) {
      $params.Body = "{`"searchWord`":`"$Domain`"}"
      $params.ContentType = 'application/json;charset=UTF-8'
    }

    if (($res = Invoke-WebRequest @params).StatusCode -ne 200) {
      throw [InvalidOperationException]::new($res.StatusDescription)
    }

    $res = ConvertFrom-Json -InputObject $res.Content
    $UseAlternative ? (
      $res.body.list.ForEach{
        "Registry: $($_.registry)"
        $_.html ? ($_.html -replace '<[^>]*>') : $(
          foreach ($item in $_.formatted) {
            "$($item.name) $($item.value -replace '<[^>]*>')"
          }
        )
      }
    ) : $res.whois
  }
}

Export-ModuleMember -Alias whois -Function Show-WhoIs
