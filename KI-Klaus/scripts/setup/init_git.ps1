# Git Setup Script für Windows PowerShell

# Funktion zum Kopieren und Aktivieren von Git Hooks
function Install-GitHooks {
    Write-Host "Installing Git hooks..."
    
    # Stelle sicher, dass der hooks Ordner existiert
    $hooksDir = ".git/hooks"
    if (-not (Test-Path $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir
    }
    
    # Kopiere Hooks und mache sie ausführbar
    Copy-Item "KI-Klaus/templates/git/hooks/*" -Destination $hooksDir -Force
    
    # Setze Ausführungsrechte für die Hooks
    Get-ChildItem $hooksDir | ForEach-Object {
        $file = $_.FullName
        if (-not $_.Extension) {
            # Füge .sh Extension hinzu für WSL Ausführung
            Rename-Item $file "$file.sh"
        }
    }
    
    Write-Host "Git hooks installed successfully"
}

# Funktion zum Einrichten der Git-Konfiguration
function Set-GitConfig {
    Write-Host "Configuring Git settings..."
    
    # Commit Message Template
    Copy-Item "KI-Klaus/templates/git/.gitmessage" -Destination ".gitmessage"
    git config --local commit.template .gitmessage
    
    # Branch-Konfiguration
    git config --local init.defaultBranch main
    
    Write-Host "Git configuration completed"
}

# Funktion zum Erstellen der initialen Branches
function Initialize-GitBranches {
    Write-Host "Initializing Git branches..."
    
    # Erstelle und wechsle zum main Branch
    git checkout -b main
    
    # Erstelle develop Branch
    git checkout -b develop
    
    # Initialer Commit
    git add .
    git commit -m "[TASK-0] chore: Initiales Projekt-Setup

- Git-Workflow eingerichtet
- Hooks installiert
- Grundstruktur erstellt

Task: #TASK-0
Status: COMPLETED"
    
    Write-Host "Git branches initialized"
}

# Hauptfunktion
function Initialize-GitSetup {
    Write-Host "Starting Git setup..."
    
    # Prüfe ob Git bereits initialisiert ist
    if (Test-Path ".git") {
        Write-Host "Git repository already initialized"
    } else {
        Write-Host "Initializing Git repository..."
        git init
    }
    
    # Führe Setup-Schritte aus
    Install-GitHooks
    Set-GitConfig
    Initialize-GitBranches
    
    Write-Host "Git setup completed successfully"
}

# Führe die Initialisierung aus
Initialize-GitSetup
