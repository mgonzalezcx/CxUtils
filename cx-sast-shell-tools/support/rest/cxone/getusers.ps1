param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/users?max=1000", $session.auth_url)
$request_url = New-Object System.Uri $rest_url

Write-Debug $request_url
Write-Debug "Users API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response