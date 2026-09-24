# Localhost-only PowerShell static + API server (hardened baseline)
Param(
    [Parameter(Mandatory = $true)][Int]$Port,
    [Parameter(Mandatory = $false)][String]$WebPath = "www",
    [Parameter(Mandatory = $false)][String]$ControllerPath = "controller"
)

$ErrorActionPreference = "Stop"

$MimeHash = @{
    ".css"  = "text/css"
    ".gif"  = "image/gif"
    ".htm"  = "text/html"
    ".html" = "text/html"
    ".ico"  = "image/x-icon"
    ".jpeg" = "image/jpeg"
    ".jpg"  = "image/jpeg"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".mjs"  = "application/javascript"
    ".png"  = "image/png"
    ".svg"  = "image/svg+xml"
    ".txt"  = "text/plain"
    ".webp" = "image/webp"
    ".xml"  = "application/xml"
}

# Allowlisted API routes -> script names under controller/api/
$ApiRoutes = @{
    "GET:/api/hello" = "hello.ps1"
}

$scriptRoot = $PSScriptRoot
$webRoot = [IO.Path]::GetFullPath((Join-Path $scriptRoot $WebPath))
$apiRoot = [IO.Path]::GetFullPath((Join-Path $scriptRoot (Join-Path $ControllerPath "api")))

function Test-UnderRoot {
    param(
        [Parameter(Mandatory = $true)][String]$Root,
        [Parameter(Mandatory = $true)][String]$Candidate
    )
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $candFull = [IO.Path]::GetFullPath($Candidate)
    return $candFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase) -or
        ($candFull.Equals($rootFull.TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase))
}

function Send-Json {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)]$Body,
        [Int]$StatusCode = 200
    )
    $json = if ($Body -is [String]) { $Body } else { $Body | ConvertTo-Json -Depth 6 -Compress }
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = "application/json; charset=utf-8"
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Send-Text {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][String]$Text,
        [Int]$StatusCode = 200,
        [String]$ContentType = "text/plain; charset=utf-8"
    )
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = $ContentType
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Resolve-SafeWebFile {
    param([Parameter(Mandatory = $true)][String]$LocalPath)
    $rel = $LocalPath.TrimStart('/', '\')
    if ([String]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }
    # Block empty segments / traversal tokens before combine
    foreach ($part in ($rel -split '[\\/]+')) {
        if ($part -eq ".." -or $part -eq "." -or $part -match '^[a-zA-Z]:$') {
            return $null
        }
    }
    $candidate = [IO.Path]::GetFullPath((Join-Path $webRoot $rel))
    if (-not (Test-UnderRoot -Root $webRoot -Candidate $candidate)) { return $null }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $null }
    return $candidate
}

function Resolve-SafeApiScript {
    param([Parameter(Mandatory = $true)][String]$FileName)
    if ($FileName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.ps1$') { return $null }
    $candidate = [IO.Path]::GetFullPath((Join-Path $apiRoot $FileName))
    if (-not (Test-UnderRoot -Root $apiRoot -Candidate $candidate)) { return $null }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $null }
    return $candidate
}

if (-not (Test-Path -LiteralPath $webRoot -PathType Container)) {
    throw "Web root not found: $webRoot"
}
if (-not (Test-Path -LiteralPath $apiRoot -PathType Container)) {
    throw "API root not found: $apiRoot"
}

$http = [System.Net.HttpListener]::new()
# Localhost only — do not use + or *
$http.Prefixes.Add("http://localhost:$Port/")
$http.Start()

Write-Host "HTTP server ready on http://localhost:$Port/ (localhost-only)" -ForegroundColor Green

try {
    while ($http.IsListening) {
        $context = $http.GetContext()
        try {
            $method = $context.Request.HttpMethod.ToUpperInvariant()
            $localPath = $context.Request.Url.LocalPath
            $routeKey = "$method:$localPath"

            Write-Host ("{0:yyyy-MM-dd HH:mm:ss} {1} {2}" -f (Get-Date), $method, $localPath)

            if ($ApiRoutes.ContainsKey($routeKey)) {
                $scriptFile = Resolve-SafeApiScript -FileName $ApiRoutes[$routeKey]
                if (-not $scriptFile) {
                    Send-Json -Context $context -Body @{ status = "error"; message = "API unavailable" } -StatusCode 404
                }
                else {
                    try {
                        # Controllers may read $context; keep request vars available
                        $script:RequestContext = $context
                        . $scriptFile
                    }
                    catch {
                        Write-Host "API error: $($_.Exception.Message)" -ForegroundColor Red
                        Send-Json -Context $context -Body @{ status = "error"; message = "Internal error" } -StatusCode 500
                    }
                }
                $context.Response.Close()
                continue
            }

            if ($method -eq "GET") {
                $path = if ($localPath -eq "/") { "/index.html" } else { $localPath }
                $file = Resolve-SafeWebFile -LocalPath $path
                if (-not $file) {
                    Send-Text -Context $context -Text "Not found" -StatusCode 404
                }
                else {
                    $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
                    $contentType = if ($MimeHash.ContainsKey($ext)) { $MimeHash[$ext] } else { "application/octet-stream" }
                    $bytes = [IO.File]::ReadAllBytes($file)
                    $context.Response.StatusCode = 200
                    $context.Response.ContentType = $contentType
                    $context.Response.ContentLength64 = $bytes.Length
                    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
                $context.Response.Close()
                continue
            }

            Send-Json -Context $context -Body @{ status = "error"; message = "Method not allowed" } -StatusCode 405
            $context.Response.Close()
        }
        catch {
            Write-Host "Request handling error: $($_.Exception.Message)" -ForegroundColor Red
            try { $context.Response.Close() } catch { }
        }
    }
}
finally {
    if ($http) {
        $http.Stop()
        $http.Close()
        $http.Dispose()
    }
}
