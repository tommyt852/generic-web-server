# Demo read-only API: GET /api/hello
# Available: $context (HttpListenerContext), Send-Json helper from web.ps1

$result = @{
    status  = "ok"
    message = "hello"
    time    = (Get-Date).ToString("o")
    # Do not echo raw query strings or bodies back to the client
}

Send-Json -Context $context -Body $result -StatusCode 200
