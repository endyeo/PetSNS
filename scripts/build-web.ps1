param([string]$Config = 'config/supabase.local.json')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot
try {
    if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) {
        throw 'Supabase build configuration is missing.'
    }
    try {
        $taskConfig = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
    } catch {
        throw 'Supabase build configuration must be valid JSON.'
    }
    $taskFields = @($taskConfig.PSObject.Properties.Name)
    if ($taskFields.Count -ne 2 -or
        $taskFields -notcontains 'SUPABASE_URL' -or
        $taskFields -notcontains 'SUPABASE_PUBLISHABLE_KEY') {
        throw 'Build configuration must contain only the URL and Publishable Key. Test credentials are not allowed.'
    }
    $taskUri = $null
    if ($taskConfig.SUPABASE_URL -isnot [string] -or
        -not [Uri]::TryCreate($taskConfig.SUPABASE_URL, [UriKind]::Absolute, [ref]$taskUri) -or
        $taskUri.Scheme -ne 'https' -or $taskUri.Host.Length -eq 0 -or
        $taskUri.UserInfo.Length -gt 0 -or $taskUri.AbsolutePath -ne '/' -or
        $taskUri.Query.Length -gt 0 -or $taskUri.Fragment.Length -gt 0) {
        throw 'Supabase URL must be an HTTPS project origin.'
    }
    if ($taskConfig.SUPABASE_PUBLISHABLE_KEY -isnot [string] -or
        $taskConfig.SUPABASE_PUBLISHABLE_KEY -cnotmatch '^sb_publishable_[A-Za-z0-9_-]+$') {
        throw 'Only an sb_publishable_ client key is allowed.'
    }
    & flutter build web --release "--dart-define-from-file=$Config"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter web release build failed.' }
    Write-Output 'PASS: release artifact created in build/web. Hosting was not deployed.'
} finally {
    Pop-Location
}
