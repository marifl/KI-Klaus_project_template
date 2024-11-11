# Version Manager für automatische Versionierung und Git-Integration
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$BumpType = 'patch',
    
    [Parameter(Mandatory=$false)]
    [string]$CommitMessage,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoCommit,
    
    [Parameter(Mandatory=$false)]
    [switch]$JsonOutput
)

# Version aus verschiedenen Dateitypen lesen
function Get-ProjectVersion {
    # Prüfe package.json
    if (Test-Path "package.json") {
        $package = Get-Content "package.json" | ConvertFrom-Json
        return @{
            Version = $package.version
            File = "package.json"
            Type = "npm"
        }
    }
    
    # Prüfe setup.py
    if (Test-Path "setup.py") {
        $setupContent = Get-Content "setup.py" -Raw
        if ($setupContent -match 'version\s*=\s*[''"]([0-9]+\.[0-9]+\.[0-9]+)[''"]') {
            return @{
                Version = $matches[1]
                File = "setup.py"
                Type = "python"
            }
        }
    }
    
    # Prüfe .csproj
    $csproj = Get-ChildItem -Filter "*.csproj" | Select-Object -First 1
    if ($csproj) {
        $content = Get-Content $csproj.FullName -Raw
        if ($content -match '<Version>([0-9]+\.[0-9]+\.[0-9]+)</Version>') {
            return @{
                Version = $matches[1]
                File = $csproj.Name
                Type = "dotnet"
            }
        }
    }
    
    # Prüfe version.txt
    if (Test-Path "version.txt") {
        $version = Get-Content "version.txt" -Raw
        return @{
            Version = $version.Trim()
            File = "version.txt"
            Type = "plain"
        }
    }
    
    # Erstelle version.txt wenn keine Version gefunden
    "0.1.0" | Set-Content "version.txt"
    return @{
        Version = "0.1.0"
        File = "version.txt"
        Type = "plain"
    }
}

# Version inkrementieren
function Update-Version {
    param (
        [string]$CurrentVersion,
        [string]$Type
    )
    
    $parts = $CurrentVersion -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($Type) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        'patch' {
            $patch++
        }
    }
    
    return "$major.$minor.$patch"
}

# Version in Datei aktualisieren
function Set-ProjectVersion {
    param (
        [string]$Version,
        [string]$File,
        [string]$Type
    )
    
    switch ($Type) {
        'npm' {
            $json = Get-Content $File | ConvertFrom-Json
            $json.version = $Version
            $json | ConvertTo-Json -Depth 100 | Set-Content $File
        }
        'python' {
            $content = Get-Content $File -Raw
            $newContent = $content -replace 'version\s*=\s*[''"]([0-9]+\.[0-9]+\.[0-9]+)[''"]', "version='$Version'"
            $newContent | Set-Content $File
        }
        'dotnet' {
            $content = Get-Content $File -Raw
            $newContent = $content -replace '<Version>([0-9]+\.[0-9]+\.[0-9]+)</Version>', "<Version>$Version</Version>"
            $newContent | Set-Content $File
        }
        'plain' {
            $Version | Set-Content $File
        }
    }
}

# Git-Integration
function Update-GitVersion {
    param (
        [string]$Version,
        [string]$Message
    )
    
    # Prüfe ob es ungespeicherte Änderungen gibt
    $status = git status --porcelain
    if ($status) {
        # Änderungen committen
        git add .
        if (-not $Message) {
            $Message = "chore: bump version to $Version"
        }
        git commit -m $Message
        
        # Version taggen
        git tag -a "v$Version" -m "Version $Version"
        
        return $true
    }
    
    return $false
}

# Hauptlogik
$result = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Action = "version_bump"
    Type = $BumpType
}

# Aktuelle Version holen
$versionInfo = Get-ProjectVersion
$currentVersion = $versionInfo.Version

# Neue Version berechnen
$newVersion = Update-Version -CurrentVersion $currentVersion -Type $BumpType

# Version in Datei aktualisieren
Set-ProjectVersion -Version $newVersion -File $versionInfo.File -Type $versionInfo.Type

$result.OldVersion = $currentVersion
$result.NewVersion = $newVersion
$result.File = $versionInfo.File

# Git-Integration wenn gewünscht
if ($AutoCommit) {
    $committed = Update-GitVersion -Version $newVersion -Message $CommitMessage
    $result.GitCommitted = $committed
}

# Ausgabe
if ($JsonOutput) {
    $result | ConvertTo-Json
} else {
    Write-Host "Version Update Results:"
    Write-Host "---------------------------"
    Write-Host "Old Version: $currentVersion"
    Write-Host "New Version: $newVersion"
    Write-Host "Updated File: $($versionInfo.File)"
    if ($AutoCommit) {
        Write-Host "Git Commit: $($result.GitCommitted)"
    }
}
