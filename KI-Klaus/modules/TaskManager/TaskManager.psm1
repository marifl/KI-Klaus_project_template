# Task Management Module für KI-Klaus

# Load environment if not already loaded
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

# Funktion zum Generieren einer Task-ID
function New-TaskId {
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    return "TASK-$timestamp"
}

# Verfügbare Rollen aus Registry laden
try {
    if (Test-Path $env:REGISTRY_PATH) {
        $registry = Get-Content $env:REGISTRY_PATH -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:ValidRoles = $registry.roles.available
        Write-Host "Loaded roles from registry: $($script:ValidRoles -join ', ')"
    } else {
        Write-Warning "Registry file not found at: $env:REGISTRY_PATH"
        $script:ValidRoles = @('Architect', 'Backend', 'Frontend', 'CodeReviewer', 'ProjectManager', 'DevOps', 'QA')
        Write-Host "Using default roles: $($script:ValidRoles -join ', ')"
    }
} catch {
    Write-Warning "Could not load registry: $_"
    $script:ValidRoles = @('Architect', 'Backend', 'Frontend', 'CodeReviewer', 'ProjectManager', 'DevOps', 'QA')
    Write-Host "Using default roles: $($script:ValidRoles -join ', ')"
}

# Funktion zum Validieren einer Rolle
function Test-ValidRole {
    param (
        [string]$Role
    )
    
    if ([string]::IsNullOrWhiteSpace($Role)) {
        return $false
    }
    
    return $script:ValidRoles -contains $Role
}

# Funktion zum Erstellen eines neuen Tasks
function New-Task {
    [CmdletBinding()]
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
        [string[]]$RequiredRoles,

        [Parameter(Mandatory=$false)]
        [string]$InitialRole
    )
    
    # Validiere Rollen
    if ($RequiredRoles) {
        foreach ($role in $RequiredRoles) {
            if (-not (Test-ValidRole $role)) {
                throw "Invalid role: $role. Valid roles are: $($script:ValidRoles -join ', ')"
            }
        }
    }
    
    if ($InitialRole -and -not (Test-ValidRole $InitialRole)) {
        throw "Invalid initial role: $InitialRole. Valid roles are: $($script:ValidRoles -join ', ')"
    }
    
    Write-Host "Creating new task: $TaskId"
    
    # Erstelle Task-Verzeichnis
    $taskDir = Join-Path $env:ACTIVE_TASKS_PATH $TaskId
    New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
    
    # Lese Task-Template
    $templatePath = Join-Path $env:TASK_TEMPLATES_PATH "task_template.md"
    if (-not (Test-Path $templatePath)) {
        Write-Warning "Template not found at: $templatePath"
        Write-Host "Creating basic template..."
        $template = @"
# Task: {TASK_ID}

## Description
{DESCRIPTION}

## Type
{TASK_TYPE}

## Status
- [ ] NEW
- [ ] IN_PROGRESS
- [ ] REVIEW
- [ ] TESTING
- [ ] COMPLETED

## Required Roles
{ROLE_SECTION}

## Quality Criteria
{ROLE_CRITERIA}

## Branch
{BRANCH_NAME}

## Created
{TIMESTAMP}

## Updates
"@
    } else {
        $template = Get-Content $templatePath -Raw
    }
    
    # Ersetze Platzhalter
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $branchName = "$Type/$TaskId-$(($Description -replace '[^a-zA-Z0-9]','-').ToLower())"
    
    # Erstelle Rollen-Sektion
    $roleSection = ""
    if ($RequiredRoles) {
        $roleSection = $RequiredRoles | ForEach-Object {
            if ($_ -eq $InitialRole) {
                "- [x] $_"
            } else {
                "- [ ] $_"
            }
        } | Out-String
    }
    
    # Hole mögliche nächste Rollen aus Registry
    $nextRoles = ""
    if ($InitialRole -and (Test-Path $env:REGISTRY_PATH)) {
        $registry = Get-Content $env:REGISTRY_PATH -Raw | ConvertFrom-Json
        $transitions = $registry.roles.transitions.phase_changes | Where-Object { $_.from -eq $InitialRole -or $_.from -eq "*" }
        if ($transitions) {
            $nextRoles = $transitions | ForEach-Object {
                "  - $($_.to) (Trigger: $($_.trigger))"
            } | Out-String
        }
    }
    
    $content = $template `
        -replace '\{TASK_ID\}', $TaskId `
        -replace '\{TIMESTAMP\}', $timestamp `
        -replace '\{BRANCH_NAME\}', $branchName `
        -replace '\{TASK_TYPE\}', $Type `
        -replace '\{DESCRIPTION\}', $Description `
        -replace '\{CURRENT_ROLE\}', $(if ($InitialRole) { $InitialRole } else { "Nicht spezifiziert" }) `
        -replace '- \[ \] \{ROLE_1\}(\r?\n)?- \[ \] \{ROLE_2\}', $roleSection.TrimEnd() `
        -replace '\{NEXT_ROLE_1\}.*\{TRIGGER_1\}\)(\r?\n)?.*\{NEXT_ROLE_2\}.*\{TRIGGER_2\}\)', $nextRoles.TrimEnd()

    # Füge Qualitätskriterien hinzu
    if ($InitialRole -and (Test-Path $env:REGISTRY_PATH)) {
        $registry = Get-Content $env:REGISTRY_PATH -Raw | ConvertFrom-Json
        if ($registry.roles.quality_criteria.$InitialRole) {
            $criteria = ($registry.roles.quality_criteria.$InitialRole | ForEach-Object { "- [ ] $_" }) -join "`n"
            $content = $content -replace '\{ROLE_CRITERIA\}', $criteria
        } else {
            $content = $content -replace '\{ROLE_CRITERIA\}', "No specific criteria defined"
        }
    } else {
        $content = $content -replace '\{ROLE_CRITERIA\}', "No specific criteria defined"
    }
    
    # Speichere Task-Datei
    $content | Set-Content (Join-Path $taskDir "description.md") -Encoding UTF8
    
    # Git-Operationen nur ausführen, wenn wir in einem Git-Repository sind
    Push-Location $env:PROJECT_ROOT
    try {
        if (Test-Path ".git") {
            git checkout develop
            git checkout -b $branchName
        } else {
            Write-Warning "No Git repository found. Skipping Git operations."
        }
    } finally {
        Pop-Location
    }

    # Erstelle initiale Thoughts wenn angegeben
    if ($InitialThoughts -or $PlannedSteps -or $InitialRole) {
        Import-Module ThoughtManager -Force
        
        # Setze Default-Werte wenn nicht angegeben
        $thoughtsContent = "Task initialized"
        if ($InitialThoughts) {
            $thoughtsContent = $InitialThoughts
        }
        
        $steps = @("Analyze task", "Plan implementation")
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
        Path = Join-Path $taskDir "description.md"
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
    [CmdletBinding()]
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
        [string]$CurrentRole,

        [Parameter(Mandatory=$false)]
        [string]$RoleTransitionReason
    )
    
    # Validiere Rolle
    if ($CurrentRole -and -not (Test-ValidRole $CurrentRole)) {
        throw "Invalid role: $CurrentRole. Valid roles are: $($script:ValidRoles -join ', ')"
    }
    
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
            $roleUpdated = $false
            $newContent = @()
            $inRolesSection = $false
            
            foreach ($line in $content) {
                if ($line -match '^## Required Roles') {
                    $inRolesSection = $true
                    $newContent += $line
                    continue
                }
                elseif ($inRolesSection -and $line -match '^## ') {
                    $inRolesSection = $false
                }
                
                if ($inRolesSection -and $line -match '^- \[[ x]\] (.+)') {
                    if ($matches[1] -eq $CurrentRole) {
                        $newContent += "- [x] $($matches[1])"
                        $roleUpdated = $true
                    } else {
                        $newContent += "- [ ] $($matches[1])"
                    }
                } else {
                    $newContent += $line
                }
            }
            
            # Wenn die Rolle noch nicht existiert, füge sie hinzu
            if (-not $roleUpdated -and $inRolesSection) {
                $newContent += "- [x] $CurrentRole"
            }
            
            $content = $newContent

            # Aktualisiere Qualitätskriterien
            if ((Test-Path $env:REGISTRY_PATH)) {
                $registry = Get-Content $env:REGISTRY_PATH -Raw | ConvertFrom-Json
                if ($registry.roles.quality_criteria.$CurrentRole) {
                    $criteria = ($registry.roles.quality_criteria.$CurrentRole | ForEach-Object { "- [ ] $_" }) -join "`n"
                    $content = $content -replace '\{ROLE_CRITERIA\}', $criteria
                }
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
            Import-Module ThoughtManager -Force
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
            Path = if ($Status -eq 'COMPLETED') { Join-Path $monthDir "$TaskId\description.md" } else { $taskFile }
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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$JsonOutput,

        [Parameter(Mandatory=$false)]
        [switch]$IncludeThoughts,

        [Parameter(Mandatory=$false)]
        [switch]$IncludeRoles
    )
    
    $tasks = @()
    $activeTasksDir = $env:ACTIVE_TASKS_PATH
    
    if (Test-Path $activeTasksDir) {
        Get-ChildItem $activeTasksDir -Directory | ForEach-Object {
            $taskId = $_.Name
            $taskFile = Join-Path $_.FullName "description.md"
            
            if (Test-Path $taskFile) {
                $content = Get-Content $taskFile
                $description = $content | Where-Object { $_ -match '^## Description' } | Select-Object -Skip 1 -First 1
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
                    Import-Module ThoughtManager -Force
                    $latestThoughts = Get-LatestTaskThoughts -TaskId $taskId
                    if ($latestThoughts) {
                        $taskInfo.LatestThoughts = $latestThoughts
                    }
                }
                
                $tasks += $taskInfo
            }
        }
    } else {
        Write-Warning "Active tasks directory not found: $activeTasksDir"
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

# Export der öffentlichen Funktionen
Export-ModuleMember -Function New-Task, Update-TaskStatus, Get-ActiveTasks
