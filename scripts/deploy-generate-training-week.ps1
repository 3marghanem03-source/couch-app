# Deploy Edge Function with JWT verification disabled at the gateway (ES256 / publishable keys).
# Prerequisites: Node.js (npx). One-time: https://supabase.com/dashboard/account/tokens
#
#   $env:SUPABASE_ACCESS_TOKEN = "sbp_..."
#   .\scripts\deploy-generate-training-week.ps1
#
# Optional: $env:SUPABASE_PROJECT_REF = "your_project_ref"  (defaults to fohttdiwlcntblftpttu)

$ErrorActionPreference = "Stop"
if (-not $env:SUPABASE_ACCESS_TOKEN) {
    Write-Error "Set SUPABASE_ACCESS_TOKEN (Supabase Dashboard → Account → Access Tokens)."
}
$ref = if ($env:SUPABASE_PROJECT_REF) { $env:SUPABASE_PROJECT_REF } else { "fohttdiwlcntblftpttu" }
Set-Location (Join-Path $PSScriptRoot "..")
npx --yes supabase@latest functions deploy generate-training-week --project-ref $ref --no-verify-jwt
