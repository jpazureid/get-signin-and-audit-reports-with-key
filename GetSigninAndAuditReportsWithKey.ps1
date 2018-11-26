#
# Authorization & resource Url
#
$tenantId = "yourtenant.onmicrosoft.com" # or GUID "01234567-89AB-CDEF-0123-456789ABCDEF"
$clientId = "FEDCBA98-7654-3210-FEDC-BA9876543210"
$clientSecret = "M9Q1lk5+fFkrI6Cg9+Tynv1B87JJVCIEju2568+wZW8="

$resource = "https://graph.microsoft.com"
$outputSigninLogFile = "signin.csv"
$outputAuditLogFile = "audit.csv"

Function Get-AuthResultClientCredentials {
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true)]
        [string]$tenantId,
        
        [parameter(Mandatory=$true)]
        [string]$clientId,
        
        [parameter(Mandatory=$true)]
        [string]$clientSecret,
        
        [parameter(Mandatory=$true)]
        [string]$resource
    )
    
    $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"
    $postParams = @{
        client_id = $clientId; 
        client_secret = $clientSecret;
        grant_type = 'client_credentials';
        resource = $resource
    }
    
    $authResult = (Invoke-WebRequest -Uri $authUrl -Method POST -Body $postParams) | ConvertFrom-Json

    return $authResult
}

Function Get-AzureAdLogWithClientCredentials {
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true)]
        [string]$endpointUrl,
        
        [parameter(Mandatory=$true)]
        [string]$filename
    )

    $data = @()
    $authResult = Get-AuthResultClientCredentials -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret -resource $resource

    Do {
        if ($null -eq $authResult.access_token) {
            Write-Host "ERROR: No Access Token"
            Write-Host "Exit"
            exit
        }

        #
        # Compose the access token type and access token for authorization header
        #
        $headerParams = @{'Authorization' = "$($authResult.token_type) $($authResult.access_token)"}

        Write-Output "Fetching log data..."

        $myReport = (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $endpointUrl)
        $convertedReport = ($myReport.Content | ConvertFrom-Json).value
        $convertedReportCount = $convertedReport.Count

        for ($j = 0; $j -lt $convertedReportCount; $j++) {
            $data += $convertedReport[$j]
        }
        
        #
        # Get url from next link
        #
        $endpointUrl = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'

        $origin = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0
        $expiresOn = $origin.AddSeconds($authResult.expires_on).AddSeconds(-300) # minus 5 min
        $getdate = (Get-Date).ToUniversalTime()

        #
        # Acquire token again if it expires soon
        #
        if ($expiresOn -lt $getdate) {
            $authResult = Get-AuthResultClientCredentials -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret -resource $resource
        }
    } while ($null -ne $endpointUrl -And "" -ne $endpointUrl)

    $data | Sort-Object -Property createdDateTime  | Export-Csv $filename -encoding "utf8" -NoTypeInformation
    Write-Output "log data is exported to $filename"
}

$signInsUrl = "$resource/beta/auditLogs/signIns"
Get-AzureAdLogWithClientCredentials -endpointUrl $signInsUrl -filename $outputSigninLogFile

#
# Sample queries are as below
#
#$signInsUrl = "$resource/beta/auditLogs/signIns?`$filter=deviceDetail/operatingSystem eq 'Windows 10'"
#$signInsUrl = "$resource/beta/auditLogs/signIns?`$filter=startswith(deviceDetail/browser,'IE')"
#$signInsUrl = "$resource/beta/auditLogs/signIns?`$filter=location/city eq 'Sattle'"
#$signInsUrl = "$resource/beta/auditLogs/signIns?`$filter=location/state eq 'Bayern'"
#$signInsUrl = "$resource/beta/auditLogs/signIns?`$filter=location/countryOrRegion eq 'JP'"

$directoryAuditsUrl = "$resource/beta/auditLogs/directoryAudits"
Get-AzureAdLogWithClientCredentials -endpointUrl $directoryAuditsUrl -filename $outputAuditLogFile
