# Installation und Migration Script für KI-Klaus Module

function Install-KIKlausModules {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    # Load environment variables
    $envLoader = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\core\load-env.ps1"
    if (Test-Path $envLoader) {
        . $envLoader
        Initialize-KIKlausEnvironment -Verbose
    } else {
        throw "Environment loader not found at: $envLoader"
    }

    # PowerShell module installation path
    $psModulesPath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules"
    $kiKlausModulePath = Join-Path $psModulesPath "KI-Klaus"

    Write-Verbose "Installation in: $kiKlausModulePath"

    # Prüfe ob Module bereits installiert sind
    if (Test-Path $kiKlausModulePath) {
        if ($Force) {
            Write-Verbose "Entferne existierende Installation..."
            Remove-Item $kiKlausModulePath -Recurse -Force
        } else {
            throw "KI-Klaus Module sind bereits in $kiKlausModulePath installiert. Nutze -Force zum Überschreiben."
        }
    }

    try {
        # Create module directories
        Write-Verbose "Erstelle Verzeichnisse..."
        $taskManagerInstallPath = Join-Path $kiKlausModulePath "TaskManager"
        $thoughtManagerInstallPath = Join-Path $kiKlausModulePath "ThoughtManager"
        $scriptsInstallPath = Join-Path $kiKlausModulePath "scripts\core"
        $templatesInstallPath = Join-Path $kiKlausModulePath "templates\tasks"

        New-Item -ItemType Directory -Path $taskManagerInstallPath -Force | Out-Null
        New-Item -ItemType Directory -Path $thoughtManagerInstallPath -Force | Out-Null
        New-Item -ItemType Directory -Path $scriptsInstallPath -Force | Out-Null
        New-Item -ItemType Directory -Path $templatesInstallPath -Force | Out-Null

        # Copy module files from source
        Write-Verbose "Kopiere TaskManager..."
        Copy-Item -Path (Join-Path $PSScriptRoot "TaskManager\*") -Destination $taskManagerInstallPath -Recurse

        Write-Verbose "Kopiere ThoughtManager..."
        Copy-Item -Path (Join-Path $PSScriptRoot "ThoughtManager\*") -Destination $thoughtManagerInstallPath -Recurse

        # Copy required files
        Write-Verbose "Kopiere zusätzliche Dateien..."
        
        # Copy registry.json from source
        $sourceRegistryPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\core\registry.json"
        Copy-Item -Path $sourceRegistryPath -Destination $scriptsInstallPath -Force
        Write-Verbose "Copied registry.json"
        
        # Copy templates from source
        $sourceTemplatesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "templates\tasks"
        Copy-Item -Path (Join-Path $sourceTemplatesPath "task_template.md") -Destination $templatesInstallPath -Force
        Write-Verbose "Copied template: task_template.md"
        Copy-Item -Path (Join-Path $sourceTemplatesPath "task_thoughts_template.md") -Destination $templatesInstallPath -Force
        Write-Verbose "Copied template: task_thoughts_template.md"

        # Prüfe Installation
        Write-Verbose "Prüfe Installation..."
        $results = Test-KIKlausInstallation

        if ($results.TaskManagerExists -and $results.ThoughtManagerExists -and $results.RequiredFilesExist.Registry -and $results.RequiredFilesExist.TaskTemplate -and $results.RequiredFilesExist.ThoughtsTemplate) {
            Write-Host @"
KI-Klaus Module erfolgreich installiert in: $kiKlausModulePath

Installierte Module:
- TaskManager: $($results.TaskManagerExists)
- ThoughtManager: $($results.ThoughtManagerExists)

Nutzung in PowerShell:
Import-Module TaskManager
Import-Module ThoughtManager

Die ursprünglichen Skripte bleiben unverändert und können weiterhin genutzt werden.
"@
        } else {
            throw "Installation unvollständig. Bitte prüfen Sie die Fehler."
        }

    } catch {
        Write-Error "Fehler bei der Installation: $_"
        if (Test-Path $kiKlausModulePath) {
            Write-Verbose "Entferne fehlerhafte Installation..."
            Remove-Item $kiKlausModulePath -Recurse -Force
        }
        throw
    }
}

function Test-KIKlausInstallation {
    [CmdletBinding()]
    param()

    $psModulesPath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules"
    $kiKlausModulePath = Join-Path $psModulesPath "KI-Klaus"
    $taskManagerPath = Join-Path $kiKlausModulePath "TaskManager"
    $thoughtManagerPath = Join-Path $kiKlausModulePath "ThoughtManager"
    $scriptsPath = Join-Path $kiKlausModulePath "scripts"
    $templatesPath = Join-Path $kiKlausModulePath "templates"

    Write-Verbose "Prüfe Installation in: $kiKlausModulePath"

    $results = @{
        InstallationPath = $kiKlausModulePath
        TaskManagerExists = (Test-Path "$taskManagerPath\TaskManager.psm1") -and (Test-Path "$taskManagerPath\TaskManager.psd1")
        ThoughtManagerExists = (Test-Path "$thoughtManagerPath\ThoughtManager.psm1") -and (Test-Path "$thoughtManagerPath\ThoughtManager.psd1")
        RequiredFilesExist = @{
            Registry = Test-Path (Join-Path $scriptsPath "core\registry.json")
            TaskTemplate = Test-Path (Join-Path $templatesPath "tasks\task_template.md")
            ThoughtsTemplate = Test-Path (Join-Path $templatesPath "tasks\task_thoughts_template.md")
        }
        ModulesAvailable = @{
            TaskManager = Get-Module TaskManager -ListAvailable
            ThoughtManager = Get-Module ThoughtManager -ListAvailable
        }
    }

    Write-Verbose "TaskManager: $($results.TaskManagerExists)"
    Write-Verbose "ThoughtManager: $($results.ThoughtManagerExists)"
    Write-Verbose "Registry: $($results.RequiredFilesExist.Registry)"
    Write-Verbose "Templates: $($results.RequiredFilesExist.TaskTemplate), $($results.RequiredFilesExist.ThoughtsTemplate)"

    return $results
}

# Wenn direkt ausgeführt, starte Installation
if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    Install-KIKlausModules -Verbose
}
