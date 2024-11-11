# Task Manager Skript mit Modul-Kompatibilität
# Versucht das TaskManager-Modul zu nutzen, fällt auf Legacy-Code zurück wenn nicht verfügbar

# Load environment if not already loaded
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

# Prüfe ob das Modul verfügbar ist
$useModule = $false
try {
    Import-Module TaskManager -ErrorAction Stop
    Import-Module ThoughtManager -ErrorAction Stop
    $useModule = $true
    Write-Verbose "TaskManager und ThoughtManager Module geladen"
} catch {
    Write-Verbose "Module nicht verfügbar, nutze Legacy-Code"
}

# Hinweis zur Modul-Installation
Write-Verbose @"
Tipp: Installiere die KI-Klaus Module für bessere Performance und Wartbarkeit:
1. Navigiere zum Modul-Verzeichnis: cd KI-Klaus/modules
2. Führe die Installation aus: ./install.ps1

Die Module bieten:
- Bessere Performance
- Einfachere Wartung
- Standardisierte Installation
"@

if ($useModule) {
    # Wenn das Modul geladen ist, exportiere die Modul-Funktionen
    Export-ModuleMember -Function New-Task, Update-TaskStatus, Get-ActiveTasks
} else {
    # Legacy-Code - Original Implementierung
    # Funktion zum Generieren einer Task-ID
    function New-TaskId {
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        return "TASK-$timestamp"
    }

    # Verfügbare Rollen aus Registry laden
    $registryPath = Join-Path $env:CORE_SCRIPTS_PATH "registry.json"
    $registry = Get-Content $registryPath -Encoding UTF8 | ConvertFrom-Json
    $ValidRoles = $registry.roles.available

    # Funktion zum Erstellen eines neuen Tasks
    function New-Task {
        param (
            [Parameter(Mandatory=$true)]
            [string]$Description,
            
            [Parameter(Mandatory=$true)]
            [ValidateSet('feature', 'bugfix', 'refactor', 'docs')]
            [string]$Type,
            
            [Parameter(Mandatory=$false)]
            [string]$TaskId = (New-TaskId),

            [Parameter(Mandatory=$false)]
            [switch]$JsonOutput,

            [Parameter(Mandatory=$false)]
            [string]$InitialThoughts,

            [Parameter(Mandatory=$false)]
            [string[]]$PlannedSteps,

            [Parameter(Mandatory=$false)]
            [ValidateScript({$_ | ForEach-Object { $ValidRoles -contains $_ }})]
            [string[]]$RequiredRoles,

            [Parameter(Mandatory=$false)]
            [ValidateScript({$ValidRoles -contains $_})]
            [string]$InitialRole
        )
        
        Write-Host "Creating new task: $TaskId"
        
        # Erstelle Task-Verzeichnis
        $taskDir = Join-Path $env:ACTIVE_TASKS_PATH $TaskId
        New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
        
        # Lese Task-Template
        $templatePath = Join-Path $env:TASK_TEMPLATES_PATH "task_template.md"
        $template = Get-Content $templatePath -Raw
        
        # Ersetze Platzhalter
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $branchName = "$Type/$TaskId-$(($Description -replace '[^a-zA-Z0-9]','-').ToLower())"
        
        $content = $template `
            -replace '\{TASK_ID\}', $TaskId `
            -replace '\{TIMESTAMP\}', $timestamp `
            -replace '\{BRANCH_NAME\}', $branchName `
            -replace '\{TASK_TYPE\}', $Type `
            -replace '\{DESCRIPTION\}', $Description `
            -replace '\{CURRENT_ROLE\}', $(if ($InitialRole) { $InitialRole } else { "Nicht spezifiziert" })

        # Füge Rollen-Informationen hinzu
        if ($RequiredRoles) {
            $content = $content -replace '\{ROLE_1\}', $RequiredRoles[0]
            if ($RequiredRoles.Count -gt 1) {
                $content = $content -replace '\{ROLE_2\}', $RequiredRoles[1]
            }
            
            # Markiere initiale Rolle
            if ($InitialRole) {
                $content = $content -replace "- \[ \] $InitialRole", "- [x] $InitialRole"
            }

            # Füge Qualitätskriterien hinzu
            if ($InitialRole -and $registry.roles.quality_criteria.$InitialRole) {
                $criteria = ($registry.roles.quality_criteria.$InitialRole | ForEach-Object { "- [ ] $_" }) -join "`n"
                $content = $content -replace '\{ROLE_CRITERIA\}', $criteria
            }
        }
        
        # Speichere Task-Datei
        $descPath = Join-Path $taskDir "description.md"
        $content | Set-Content $descPath -Encoding UTF8
        
        # Erstelle Git-Branch
        git checkout develop
        git checkout -b $branchName
        
        # Erstelle initiale Thoughts wenn angegeben
        if ($InitialThoughts -or $PlannedSteps -or $InitialRole) {
            # Setze Default-Werte wenn nicht angegeben
            $thoughtsContent = "Task initialisiert"
            if ($InitialThoughts) {
                $thoughtsContent = $InitialThoughts
            }
            
            $steps = @("Task analysieren", "Implementierung planen")
            if ($PlannedSteps) {
                $steps = $PlannedSteps
            }
            
            New-TaskThoughts `
                -TaskId $TaskId `
                -CurrentThoughts $thoughtsContent `
                -NextSteps $steps `
                -CurrentRole $InitialRole
        }
        
        # Erstelle Ergebnis-Objekt
        $result = @{
            TaskId = $TaskId
            Branch = $branchName
            Path = $descPath
            Status = "NEW"
            RequiredRoles = $RequiredRoles
            CurrentRole = $InitialRole
        }
        
        # Ausgabe basierend auf Format
        if ($JsonOutput) {
            $result | ConvertTo-Json
        } else {
            Write-Host "Task created successfully: $TaskId"
            Write-Host "Branch created: $branchName"
            if ($RequiredRoles) {
                Write-Host "Required roles: $($RequiredRoles -join ', ')"
            }
            if ($InitialRole) {
                Write-Host "Initial role: $InitialRole"
            }
            return $TaskId
        }
    }

    # Funktion zum Aktualisieren des Task-Status
    function Update-TaskStatus {
        param (
            [Parameter(Mandatory=$true)]
            [string]$TaskId,
            
            [Parameter(Mandatory=$true)]
            [ValidateSet('NEW', 'IN_PROGRESS', 'REVIEW', 'TESTING', 'COMPLETED')]
            [string]$Status,

            [Parameter(Mandatory=$false)]
            [switch]$JsonOutput,

            [Parameter(Mandatory=$false)]
            [string]$StatusNotes,

            [Parameter(Mandatory=$false)]
            [ValidateScript({$ValidRoles -contains $_})]
            [string]$CurrentRole,

            [Parameter(Mandatory=$false)]
            [string]$RoleTransitionReason
        )
        
        Write-Host "Updating status for task: $TaskId to $Status"
        
        $taskDir = Join-Path $env:ACTIVE_TASKS_PATH $TaskId
        $taskFile = Join-Path $taskDir "description.md"
        
        if (Test-Path $taskFile) {
            $content = Get-Content $taskFile
            
            # Aktualisiere Status
            $content = $content | ForEach-Object {
                if ($_ -match '- \[ \] (\w+)') {
                    if ($matches[1] -eq $Status) {
                        $_ -replace '- \[ \]', '- [x]'
                    } else {
                        $_ -replace '- \[x\]', '- [ ]'
                    }
                } else {
                    $_
                }
            }

            # Aktualisiere Rolle wenn angegeben
            if ($CurrentRole) {
                $newContent = @()
                $inRolesSection = $false
                
                foreach ($line in $content) {
                    if ($line -match '^## Required Roles') {
                        $inRolesSection = $true
                    }
                    elseif ($inRolesSection -and $line -match '^## ') {
                        $inRolesSection = $false
                    }
                    
                    if ($inRolesSection -and $line -match '^- \[[ x]\] (.+)') {
                        if ($matches[1] -eq $CurrentRole) {
                            $newContent += "- [x] $($matches[1])"
                        } else {
                            $newContent += "- [ ] $($matches[1])"
                        }
                    } else {
                        $newContent += $line
                    }
                }
                $content = $newContent

                # Aktualisiere Qualitätskriterien
                if ($registry.roles.quality_criteria.$CurrentRole) {
                    $criteria = ($registry.roles.quality_criteria.$CurrentRole | ForEach-Object { "- [ ] $_" }) -join "`n"
                    $content = $content -replace '\{ROLE_CRITERIA\}', $criteria
                }
            }
            
            # Füge Update-Eintrag hinzu
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $updateNote = "- ${timestamp} | Status: ${Status}"
            if ($CurrentRole) {
                $updateNote += " | Role: ${CurrentRole}"
            }
            $content += "`n$updateNote"
            
            # Speichere aktualisierte Datei
            $content | Set-Content $taskFile -Encoding UTF8
            
            # Erstelle Thoughts-Eintrag für Status-Update
            if ($StatusNotes -or $RoleTransitionReason) {
                $thoughts = "Status: ${Status}"
                if ($CurrentRole) {
                    $thoughts += "`nRole: ${CurrentRole}"
                }
                if ($RoleTransitionReason) {
                    $thoughts += "`nTransition Reason: ${RoleTransitionReason}"
                }
                if ($StatusNotes) {
                    $thoughts += "`nNotes: ${StatusNotes}"
                }
                
                New-TaskThoughts `
                    -TaskId $TaskId `
                    -CurrentThoughts $thoughts `
                    -NextSteps @("Plan next steps based on new status") `
                    -CurrentRole $CurrentRole `
                    -RoleTransitionReason $RoleTransitionReason
            }
            
            # Wenn Status COMPLETED ist, verschiebe in completed Ordner
            if ($Status -eq 'COMPLETED') {
                $monthDir = Join-Path $env:COMPLETED_TASKS_PATH (Get-Date).ToString('yyyy-MM')
                New-Item -ItemType Directory -Path $monthDir -Force | Out-Null
                
                # Verschiebe Task-Verzeichnis komplett (mit Thoughts)
                $targetDir = Join-Path $monthDir $TaskId
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                Move-Item "$taskDir/*" $targetDir -Force
                Remove-Item $taskDir -Recurse -Force
            }
            
            # Erstelle Ergebnis-Objekt
            $result = @{
                TaskId = $TaskId
                Status = $Status
                UpdateTime = $timestamp
                Path = if ($Status -eq 'COMPLETED') { Join-Path $monthDir "$TaskId/description.md" } else { $taskFile }
                CurrentRole = $CurrentRole
            }
            
            # Ausgabe basierend auf Format
            if ($JsonOutput) {
                $result | ConvertTo-Json
            } else {
                Write-Host "Task status updated successfully"
                Write-Host "New status: $Status"
                Write-Host "Update time: $timestamp"
                if ($CurrentRole) {
                    Write-Host "Current role: $CurrentRole"
                }
            }
        } else {
            $errorResult = @{
                Error = "Task file not found: $taskFile"
                TaskId = $TaskId
            }
            
            if ($JsonOutput) {
                $errorResult | ConvertTo-Json
            } else {
                Write-Host "Task file not found: $taskFile"
            }
        }
    }

    # Funktion zum Auflisten aktiver Tasks
    function Get-ActiveTasks {
        param (
            [Parameter(Mandatory=$false)]
            [switch]$JsonOutput,

            [Parameter(Mandatory=$false)]
            [switch]$IncludeThoughts,

            [Parameter(Mandatory=$false)]
            [switch]$IncludeRoles
        )
        
        $tasks = @()
        
        Get-ChildItem $env:ACTIVE_TASKS_PATH -Directory | ForEach-Object {
            $taskId = $_.Name
            $taskFile = Join-Path $_.FullName "description.md"
            
            if (Test-Path $taskFile) {
                $content = Get-Content $taskFile
                $description = $content | Where-Object { $_ -match '^## Beschreibung' } | Select-Object -Skip 1 -First 1
                $status = $content | Where-Object { $_ -match '- \[x\] (\w+)' } | ForEach-Object { $matches[1] }
                
                $taskInfo = @{
                    TaskId = $taskId
                    Description = $description
                    Status = if ($status) { $status } else { "NEW" }
                    Path = $taskFile
                }

                if ($IncludeRoles) {
                    $roles = @()
                    $currentRole = $null
                    $inRolesSection = $false
                    
                    foreach ($line in $content) {
                        if ($line -match '^## Required Roles') {
                            $inRolesSection = $true
                            continue
                        }
                        if ($inRolesSection) {
                            if ($line -match '^- \[x\] (.+)') {
                                $currentRole = $matches[1]
                                $roles += $matches[1]
                            }
                            elseif ($line -match '^- \[ \] (.+)') {
                                $roles += $matches[1]
                            }
                            elseif ($line -match '^##') {
                                break
                            }
                        }
                    }
                    
                    if ($roles.Count -gt 0) {
                        $taskInfo.RequiredRoles = $roles
                        $taskInfo.CurrentRole = $currentRole
                    }
                }
                
                if ($IncludeThoughts) {
                    $latestThoughts = Get-LatestTaskThoughts -TaskId $taskId
                    if ($latestThoughts) {
                        $taskInfo.LatestThoughts = $latestThoughts
                    }
                }
                
                $tasks += $taskInfo
            }
        }
        
        # Ausgabe basierend auf Format
        if ($JsonOutput) {
            $tasks | ConvertTo-Json -Depth 10
        } else {
            Write-Host "Active Tasks:"
            Write-Host "-------------"
            foreach ($task in $tasks) {
                Write-Host "$($task.TaskId) - $($task.Status)"
                Write-Host "  $($task.Description)"
                if ($task.RequiredRoles) {
                    Write-Host "  Required Roles: $($task.RequiredRoles -join ', ')"
                    if ($task.CurrentRole) {
                        Write-Host "  Current Role: $($task.CurrentRole)"
                    }
                }
                if ($task.LatestThoughts) {
                    Write-Host "  Latest Thoughts available"
                }
                Write-Host ""
            }
        }
    }
}

# Export der Funktionen
if ($MyInvocation.InvocationName -ne '.') {
    Export-ModuleMember -Function New-Task, Update-TaskStatus, Get-ActiveTasks
}
