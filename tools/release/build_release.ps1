#Requires -Version 5.1
<#
.SYNOPSIS
    Atalho unificado para executar a automação de exportação de builds
    (pacote Windows com Launcher + Jogo, e Android .apk) em tools/release/export_builds.ps1.
#>

[CmdletBinding()]
param(
    [string[]]$Targets = @("All"),
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

$TargetScript = Join-Path $PSScriptRoot "export_builds.ps1"
& $TargetScript @PSBoundParameters
exit $LASTEXITCODE
