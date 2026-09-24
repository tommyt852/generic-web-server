# POST /api/shutdown — request a graceful stop of the HttpListener.
# Token gate is enforced by web.ps1 before this script runs. Never expose as GET.

Send-Json -Context $context -Body @{
    status  = "ok"
    message = "shutting down"
} -StatusCode 200

$script:ShouldShutdown = $true
