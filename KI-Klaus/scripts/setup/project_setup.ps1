# Projekt-Setup-Skript
param (
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeMicroservices
)

function Initialize-ProjectStructure {
    param (
        [string]$RootDir,
        [bool]$WithMicroservices
    )
    
    Write-Host "Creating project structure..."
    
    # Basis-Verzeichnisse
    $baseDirs = @(
        "$RootDir/docs",
        "$RootDir/dev/tasks/active",
        "$RootDir/dev/tasks/completed",
        "$RootDir/config/dev",
        "$RootDir/config/staging",
        "$RootDir/config/prod",
        "$RootDir/scripts/deployment_scripts",
        "$RootDir/tests/integration_tests",
        "$RootDir/tests/end_to_end_tests"
    )
    
    # Microservices-Verzeichnisse
    if ($WithMicroservices) {
        $baseDirs += @(
            "$RootDir/backend/microservice1/src",
            "$RootDir/backend/microservice1/tests",
            "$RootDir/backend/microservice2/src",
            "$RootDir/backend/microservice2/tests",
            "$RootDir/frontend/src",
            "$RootDir/frontend/public"
        )
    } else {
        $baseDirs += @(
            "$RootDir/src",
            "$RootDir/tests"
        )
    }
    
    # Verzeichnisse erstellen
    foreach ($dir in $baseDirs) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    
    # Basis-Dateien erstellen
    $baseFiles = @(
        "$RootDir/.env.example",
        "$RootDir/README.md"
    )
    
    # Microservices-Dateien
    if ($WithMicroservices) {
        $baseFiles += @(
            "$RootDir/backend/microservice1/Dockerfile",
            "$RootDir/backend/microservice1/environment.yml",
            "$RootDir/backend/microservice2/Dockerfile",
            "$RootDir/backend/microservice2/environment.yml",
            "$RootDir/frontend/package.json",
            "$RootDir/docker-compose.yml"
        )
    }
    
    foreach ($file in $baseFiles) {
        New-Item -ItemType File -Force -Path $file | Out-Null
    }
}

function Initialize-Documentation {
    param (
        [string]$RootDir
    )
    
    Write-Host "Setting up documentation..."
    
    # Dokumentations-Templates
    $templates = @(
        "custom_instructions.md",
        "changelog_TEMPLATE.md",
        "coding_standards.md",
        "directory_map.md",
        "workflow.md",
        "project_map.md",
        "projectRoadmap.md",
        "techStack.md",
        "codebaseSummary.md"
    )
    
    foreach ($template in $templates) {
        $path = "$RootDir/docs/$template"
        New-Item -ItemType File -Force -Path $path | Out-Null
        Add-Content -Path $path -Value "<!-- TEMPLATE FILE: Do not overwrite or delete -->`n"
    }
}

function Initialize-GitRepository {
    param (
        [string]$RootDir
    )
    
    Write-Host "Initializing Git repository..."
    
    Push-Location $RootDir
    
    # Git initialisieren
    git init
    
    # Git safe directory konfigurieren
    git config --global --add safe.directory $RootDir
    
    # Hooks installieren
    $hooksDir = ".git/hooks"
    if (-not (Test-Path $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    }
    Copy-Item "KI-Klaus/templates/git/hooks/*" -Destination $hooksDir -Force
    
    # Git-Konfiguration
    Copy-Item "KI-Klaus/templates/git/.gitmessage" -Destination ".gitmessage"
    git config --local commit.template .gitmessage
    git config --local init.defaultBranch main
    git config core.autocrlf true
    
    # Branches erstellen
    git checkout -b main
    git checkout -b develop
    
    Pop-Location
}

function Initialize-TaskSystem {
    param (
        [string]$RootDir
    )
    
    Write-Host "Setting up task management system..."
    
    # Task-Verzeichnisse
    $taskDirs = @(
        "$RootDir/dev/tasks/active",
        "$RootDir/dev/tasks/completed"
    )
    
    foreach ($dir in $taskDirs) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    
    # .gitkeep für leere Verzeichnisse
    New-Item -ItemType File -Force -Path "$RootDir/dev/tasks/completed/.gitkeep" | Out-Null
    
    # Initialen Task erstellen
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $taskId = "TASK-$timestamp"
    $taskDir = "$RootDir/dev/tasks/active/$taskId"
    
    # Task aus Template erstellen
    New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
    $taskTemplate = Get-Content "KI-Klaus/templates/tasks/task_template.md" -Raw
    
    $taskContent = $taskTemplate `
        -replace '\{TASK_ID\}', $taskId `
        -replace '\{TIMESTAMP\}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss") `
        -replace '\{BRANCH_NAME\}', "feature/$taskId-initial-setup" `
        -replace '\{TASK_TYPE\}', "feature" `
        -replace '\{DESCRIPTION\}', "Initiales Projekt-Setup"
    
    $taskContent | Set-Content "$taskDir/description.md"
    
    return $taskId
}

# Hauptfunktion
function Initialize-Project {
    param (
        [string]$ProjectName,
        [bool]$WithMicroservices
    )
    
    $rootDir = "./$ProjectName"
    
    # Projekt-Verzeichnis erstellen
    New-Item -ItemType Directory -Force -Path $rootDir | Out-Null
    
    # Komponenten initialisieren
    Initialize-ProjectStructure -RootDir $rootDir -WithMicroservices $WithMicroservices
    Initialize-Documentation -RootDir $rootDir
    Initialize-GitRepository -RootDir $rootDir
    $taskId = Initialize-TaskSystem -RootDir $rootDir
    
    # Ersten Commit erstellen
    Push-Location $rootDir
    git add .
    git commit -m "[$taskId] chore: Initiales Projekt-Setup

- Projekt-Template initialisiert
- Git-Workflow eingerichtet
- Task-Management konfiguriert

Task: #$taskId
Status: COMPLETED"
    Pop-Location
    
    Write-Host "Project '$ProjectName' has been set up successfully!"
}

# Projekt initialisieren
Initialize-Project -ProjectName $ProjectName -WithMicroservices $IncludeMicroservices.IsPresent
