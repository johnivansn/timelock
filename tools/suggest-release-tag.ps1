param(
  [ValidateSet("beta", "rc", "stable")]
  [string]$Channel = "beta",

  [switch]$CreateTag,
  [switch]$Push,

  [string]$Remote = "origin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path

function Get-GitOutput {
  param([string[]]$CmdArgs)
  (& git -C $repoRoot @CmdArgs 2>$null) -join "`n"
}

function Ensure-GitRepo {
  $inside = (& git -C $repoRoot rev-parse --is-inside-work-tree 2>$null) -join "`n"
  if ($LASTEXITCODE -ne 0 -or $inside.Trim() -ne "true") {
    throw "Este script debe ejecutarse dentro de un repositorio git."
  }
}

function Get-NextTag {
  param(
    [string]$CoreVersion,
    [string]$Track,
    [string[]]$ExistingTags
  )

  $escapedCore = [regex]::Escape($CoreVersion)
  $escapedTrack = [regex]::Escape($Track)
  $pattern = "^v$escapedCore-$escapedTrack(?:[.-](\d+))?$"

  $max = 0
  foreach ($tag in $ExistingTags) {
    $m = [regex]::Match($tag, $pattern)
    if (-not $m.Success) {
      continue
    }
    $value = 1
    if ($m.Groups[1].Success) {
      $parsed = 0
      if ([int]::TryParse($m.Groups[1].Value, [ref]$parsed)) {
        $value = $parsed
      }
    }
    if ($value -gt $max) {
      $max = $value
    }
  }

  $next = $max + 1
  return "v$CoreVersion-$Track.$next"
}

Ensure-GitRepo

$commitCountRaw = Get-GitOutput -CmdArgs @("rev-list", "--count", "HEAD")
$commitCount = 0
if (-not [int]::TryParse($commitCountRaw.Trim(), [ref]$commitCount)) {
  throw "No se pudo calcular el commit count."
}

$now = Get-Date
$yy = $now.Year % 100
$mm = $now.Month
$coreVersion = "{0:00}.{1:00}.{2}" -f $yy, $mm, $commitCount
$versionCode = ($yy * 10000) + ($mm * 100) + $commitCount

$tagsRaw = Get-GitOutput -CmdArgs @("tag", "--list")
$existingTags = @()
if ($tagsRaw) {
  $existingTags = $tagsRaw -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 }
}

$tag = switch ($Channel) {
  "stable" { "v$coreVersion" }
  "beta"   { Get-NextTag -CoreVersion $coreVersion -Track "beta" -ExistingTags $existingTags }
  "rc"     { Get-NextTag -CoreVersion $coreVersion -Track "rc" -ExistingTags $existingTags }
  default  { throw "Canal no soportado: $Channel" }
}

$alreadyExists = $existingTags -contains $tag

Write-Host "Core version (YY.MM.PATCH): $coreVersion"
Write-Host "Android versionCode estimado: $versionCode"
Write-Host "Canal: $Channel"
Write-Host "Tag sugerido: $tag"
if ($alreadyExists) {
  Write-Host "Aviso: el tag sugerido ya existe en local."
}
Write-Host ""
Write-Host "Comandos sugeridos:"
Write-Host "  git tag $tag"
Write-Host "  git push $Remote $tag"

if ($CreateTag) {
  $existsNow = (Get-GitOutput -CmdArgs @("tag", "--list", $tag)).Trim()
  if ($existsNow) {
    throw "El tag '$tag' ya existe. No se creara de nuevo."
  }
  & git -C $repoRoot tag $tag
  Write-Host "Tag creado: $tag"
}

if ($Push) {
  & git -C $repoRoot push $Remote $tag
  Write-Host "Tag enviado a '$Remote': $tag"
}
