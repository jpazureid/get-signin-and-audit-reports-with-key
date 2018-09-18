#
# Authorization & resource Url
#
$tenantId = "yourtenant.onmicrosoft.com" # or GUID "01234567-89AB-CDEF-0123-456789ABCDEF"
$clientId = "FEDCBA98-7654-3210-FEDC-BA9876543210"
$client_secret = "8sZfBK/hbUpEm6L8PqSk9mB29Ck/PqbHJo/Ll9t0tw4="

$resource = "https://graph.microsoft.com"
$outputSigninLogFile = "signin.csv"
$outputAuditLogFile = "audit.csv"

#
# Acquire the authentication result
#
$postParams = @{
    client_id = $clientId; 
    client_secret = $client_secret;
    grant_type = 'client_credentials';
    resource = $resource
}

$authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$authResult = (Invoke-WebRequest -Uri $authUrl -Method POST -Body $postParams) | ConvertFrom-Json

if ($null -ne $authResult.access_token) {
    #
    # Compose the access token type and access token for authorization header
    #
    $headerParams = @{'Authorization' = "$($authResult.token_type) $($authResult.access_token)"}

    #
    # Sign in log
    #
    $data = @()
    $url = "$resource/beta/auditLogs/signIns"
    
    Do {
        Write-Output "Fetching signin log data..."

        $myReport = (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url)
        $convertedReport = ($myReport.Content | ConvertFrom-Json).value
        $convertedReportCount = $convertedReport.Count
 
        for ($j = 0; $j -lt $convertedReportCount; $j++) {
            $data += $convertedReport[$j]
        }
        
        #
        #Get url from next link
        #
        $url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'
    }while ($null -ne $url)

    $data | Sort-Object -Property createdDateTime  | Export-Csv $outputSigninLogFile -encoding "utf8" -NoTypeInformation
    Write-Output "Sign-in log data is exported to $outputSigninLogFile"

    #
    # Audit log
    # Compose the access token type and access token for authorization header
    #
    $data = @()
    $url = "$resource/beta/auditLogs/directoryAudits"
    
    Do {
        Write-Output "Fetching audit log data..."

        $myReport = (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url)
        $convertedReport = ($myReport.Content | ConvertFrom-Json).value
        $convertedReportCount = $convertedReport.Count

        for ($j = 0; $j -lt $convertedReportCount; $j++) {
            $data += $convertedReport[$j]
        }
        
        #
        #Get url from next link
        #
        $url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'
    }while ($null -ne $url)

    $data | Sort-Object -Property createdDateTime  | Export-Csv $outputAuditLogFile -encoding "utf8" -NoTypeInformation
    Write-Output "Sign-in log data is exported to $outputAuditLogFile"
}
else {
    Write-Host "ERROR: No Access Token"
}