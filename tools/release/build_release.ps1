#Requires -Version 5.1
<#
.SYNOPSIS
    Atalho unificado para executar a automação de exportação de builds
    (Windows .exe/.zip, Android .apk e Launcher) em .antigravity/automation/export_builds.ps1.
#>

[CmdletBinding()]
param(
    [string[]]$Targets = @("Windows", "Android"),
    [string]$Version = "",
    [switch]$BumpPatch,
    [switch]$BumpMinor,
    [switch]$NoBump,
    [string]$GitHubRepo = "",
    [string]$ReleaseNotes = "",
    [switch]$DebugBuild,
    [switch]$CopyToMdp,
    [switch]$SkipValidation,
    [switch]$PublishGitHubRelease
)

$RepoRoot     = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$TargetScript = Join-Path $RepoRoot ".antigravity\automation\export_builds.ps1"
& $TargetScript @PSBoundParameters
exit $LASTEXITCODE
