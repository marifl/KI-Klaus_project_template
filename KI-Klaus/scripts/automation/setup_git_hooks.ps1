# Setup Git Hooks für automatische Versionierung
param (
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$JsonOutput
)

$result = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Action = "setup_git_hooks"
    Success = $false
    Messages = @()
}

# Prüfe ob wir in einem Git-Repository sind
$gitRoot = git rev-parse --show-toplevel 2>$null
if (-not $?) {
    $result.Messages += "Nicht in einem Git-Repository"
    if ($JsonOutput) {
        $result | ConvertTo-Json
    } else {
        Write-Host "Fehler: Nicht in einem Git-Repository"
    }
    exit 1
}

# Git-Hooks-Verzeichnis
$hooksDir = Join-Path $gitRoot ".git/hooks"
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
}

# Quell-Hook-Verzeichnis
$sourceHooksDir = Join-Path $PSScriptRoot "git_hooks"

# Hook-Dateien
$hooks = @(
    "post-commit"
)

# Hooks installieren
foreach ($hook in $hooks) {
    $sourcePath = Join-Path $sourceHooksDir $hook
    $targetPath = Join-Path $hooksDir $hook
    
    # Prüfe ob Hook bereits existiert
    if ((Test-Path $targetPath) -and -not $Force) {
        $result.Messages += "Hook $hook existiert bereits. Nutze -Force zum Überschreiben."
        continue
    }
    
    # Kopiere Hook
    try {
        Copy-Item -Path $sourcePath -Destination $targetPath -Force
        $result.Messages += "Hook $hook erfolgreich installiert"
        
        # Git-Konfiguration setzen
        git config --local core.hooksPath $hooksDir
    }
    catch {
        $errorMessage = $_.Exception.Message
        $result.Messages += "Fehler beim Installieren von Hook $hook - $errorMessage"
        continue
    }
}

$result.Success = $true

# Ausgabe
if ($JsonOutput) {
    $result | ConvertTo-Json
} else {
    Write-Host "Git Hooks Setup Results:"
    Write-Host "---------------------------"
    foreach ($message in $result.Messages) {
        Write-Host $message
    }
    if ($result.Success) {
        Write-Host "`nGit Hooks wurden erfolgreich eingerichtet"
        Write-Host "HINWEIS: Unter Unix-Systemen müssen die Hook-Dateien noch ausführbar gemacht werden:"
        Write-Host "chmod +x .git/hooks/*"
    }
}
