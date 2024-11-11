# Script Registration Tool
param (
    [Parameter(Mandatory=$true)]
    [string]$Path,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('task_management', 'analysis', 'setup', 'documentation', 'automation')]
    [string]$Category,
    
    [Parameter(Mandatory=$true)]
    [string]$Purpose,
    
    [Parameter(Mandatory=$true)]
    [string[]]$WhenToUse,
    
    [Parameter(Mandatory=$false)]
    [switch]$TokenEfficient
)

# Registry-Pfad
$registryPath = Join-Path $PSScriptRoot "core/registry.json"

# Prüfe ob Skript existiert
if (-not (Test-Path $Path)) {
    Write-Error "Script not found: $Path"
    exit 1
}

# Lade Registry
$registry = Get-Content $registryPath | ConvertFrom-Json

# Extrahiere Skript-Name und relative Kategorie
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
$relativePath = $Path -replace [regex]::Escape($PSScriptRoot), ''
$relativePath = $relativePath.TrimStart('\', '/')

# Erstelle Dokumentations-Stub
$docPath = "docs/$scriptName.md"
if (-not (Test-Path $docPath)) {
    $docContent = @"
# $scriptName

## Purpose
$Purpose

## When to Use
$(($WhenToUse | ForEach-Object { "- $_" }) -join "`n")

## Parameters
[Document parameters here]

## Examples
[Add usage examples here]

## Notes
- Token Efficient: $($TokenEfficient.IsPresent)
- Category: $Category

## Related Scripts
[Add related scripts here]
"@
    New-Item -Path $docPath -ItemType File -Force | Out-Null
    Set-Content -Path $docPath -Value $docContent
}

# Füge Skript zur Registry hinzu
$scriptEntry = @{
    path = $relativePath
    purpose = $Purpose
    when_to_use = $WhenToUse
    token_efficient = $TokenEfficient.IsPresent
    doc = $docPath
}

# Aktualisiere oder erstelle Kategorie wenn nötig
if (-not $registry.categories.$Category) {
    $registry.categories | Add-Member -NotePropertyName $Category -NotePropertyValue @{
        description = "Scripts for $Category"
        scripts = @{}
    }
}

# Füge Skript zur Kategorie hinzu
$registry.categories.$Category.scripts | Add-Member -NotePropertyName $scriptName -NotePropertyValue $scriptEntry -Force

# Speichere aktualisierte Registry
$registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath

Write-Host "Script registered successfully:"
Write-Host "- Name: $scriptName"
Write-Host "- Category: $Category"
Write-Host "- Path: $relativePath"
Write-Host "- Documentation: $docPath"
