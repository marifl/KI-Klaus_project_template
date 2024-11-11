# Thought Management Module für KI-Klaus

# Load environment if not already loaded
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

function New-TaskThoughts {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        
        [Parameter(Mandatory=$true)]
        [string]$CurrentThoughts,
        
        [Parameter(Mandatory=$true)]
        [string[]]$NextSteps,
        
        [Parameter(Mandatory=$false)]
        [string[]]$OpenQuestions,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RelevantFiles,
        
        [Parameter(Mandatory=$false)]
        [string]$LastAction,
        
        [Parameter(Mandatory=$false)]
        [string]$PlannedAction,
        
        [Parameter(Mandatory=$false)]
        [string]$TechnicalDetails,

        [Parameter(Mandatory=$false)]
        [string]$CurrentRole,

        [Parameter(Mandatory=$false)]
        [string]$RoleTransitionReason
    )
    
    # Bestimme Task-Verzeichnis
    $taskDir = Join-Path $env:ACTIVE_TASKS_PATH $TaskId
    if (-not (Test-Path $taskDir)) {
        $monthDir = Join-Path $env:COMPLETED_TASKS_PATH (Get-Date).ToString('yyyy-MM')
        if (-not (Test-Path $monthDir)) {
            New-Item -ItemType Directory -Path $monthDir -Force | Out-Null
        }
        $taskDir = Join-Path $monthDir $TaskId
    }
    
    # Erstelle thoughts Verzeichnis
    $thoughtsDir = Join-Path $taskDir "thoughts"
    New-Item -ItemType Directory -Path $thoughtsDir -Force | Out-Null
    
    # Generiere Timestamp für den Dateinamen
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $thoughtsFile = Join-Path $thoughtsDir "thoughts_$timestamp.md"
    
    # Lese Template
    $templatePath = Join-Path $env:TASK_TEMPLATES_PATH "task_thoughts_template.md"
    if (-not (Test-Path $templatePath)) {
        # Fallback: Erstelle ein Basic-Template wenn die Datei nicht existiert
        $template = @"
# Task Thoughts: {TASK_ID}

## Status
{STATUS}

## Timestamp
{TIMESTAMP}

## Aktuelle Rolle
{CURRENT_ROLE}

## Rollenwechsel-Grund
{ROLE_TRANSITION_REASON}

## Aktuelle Gedanken
{CURRENT_THOUGHTS}

## Nächste Schritte
{NEXT_STEPS}

## Offene Fragen
{OPEN_QUESTIONS}

## Relevante Dateien
{RELEVANT_FILES}

## Letzte Aktion
{LAST_ACTION}

## Geplante Aktion
{PLANNED_ACTION}

## Technische Details
{TECHNICAL_DETAILS}
"@
    } else {
        $template = Get-Content $templatePath -Raw
    }
    
    # Hole aktuellen Task-Status
    $taskDescPath = Join-Path $taskDir "description.md"
    $status = "NEW"
    if (Test-Path $taskDescPath) {
        $taskContent = Get-Content $taskDescPath -Raw
        if ($taskContent -match '- \[x\] (\w+)') { 
            $status = $matches[1] 
        }
    }
    
    # Ersetze Platzhalter
    $content = $template `
        -replace '\{TASK_ID\}', $TaskId `
        -replace '\{STATUS\}', $status `
        -replace '\{TIMESTAMP\}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss") `
        -replace '\{CURRENT_THOUGHTS\}', $CurrentThoughts `
        -replace '\{CURRENT_ROLE\}', $(if ($CurrentRole) { $CurrentRole } else { "Nicht spezifiziert" }) `
        -replace '\{ROLE_TRANSITION_REASON\}', $(if ($RoleTransitionReason) { $RoleTransitionReason } else { "Kein Rollenwechsel" })
    
    # Füge Next Steps hinzu
    $nextStepsText = ($NextSteps | ForEach-Object { "1. $_" }) -join "`n"
    $content = $content -replace '\{NEXT_STEPS\}', $nextStepsText
    
    # Füge Open Questions hinzu
    if ($OpenQuestions) {
        $questionsText = ($OpenQuestions | ForEach-Object { "- $_" }) -join "`n"
        $content = $content -replace '\{OPEN_QUESTIONS\}', $questionsText
    } else {
        $content = $content -replace '\{OPEN_QUESTIONS\}', "Keine offenen Fragen"
    }
    
    # Füge Relevant Files hinzu
    if ($RelevantFiles) {
        $filesText = ($RelevantFiles | ForEach-Object { "  - $_" }) -join "`n"
        $content = $content -replace '\{RELEVANT_FILES\}', $filesText
    } else {
        $content = $content -replace '\{RELEVANT_FILES\}', "Keine relevanten Dateien"
    }
    
    # Füge Actions hinzu
    $content = $content -replace '\{LAST_ACTION\}', $(if ($LastAction) { $LastAction } else { "Keine" })
    $content = $content -replace '\{PLANNED_ACTION\}', $(if ($PlannedAction) { $PlannedAction } else { "Keine" })
    
    # Füge Technical Details hinzu
    $content = $content -replace '\{TECHNICAL_DETAILS\}', $(if ($TechnicalDetails) { $TechnicalDetails } else { "Keine" })
    
    # Schreibe Datei
    $content | Set-Content $thoughtsFile -Encoding UTF8
    
    # Erstelle/Aktualisiere thoughts_index.md
    $indexFile = Join-Path $thoughtsDir "thoughts_index.md"
    $indexContent = @"
# Gedanken-Index für $TaskId

## Rollen-Historie
"@
    
    # Sammle Rollen-Historie
    $roleHistory = @()
    Get-ChildItem $thoughtsDir -Filter "thoughts_*.md" | 
    Where-Object { $_.Name -ne "thoughts_index.md" } |
    Sort-Object Name |
    ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match 'Aktuelle Rolle: (.+)') {
            $role = $matches[1]
            $thoughtDate = [datetime]::ParseExact($_.BaseName.Split('_')[1], "yyyyMMdd", $null)
            $roleHistory += "- $($thoughtDate.ToString('yyyy-MM-dd')): $role"
        }
    }
    
    if ($roleHistory.Count -gt 0) {
        $indexContent += "`n" + ($roleHistory -join "`n")
    }
    
    $indexContent += @"

## Chronologische Übersicht
"@
    
    # Füge alle Thoughts-Dateien zum Index hinzu
    Get-ChildItem $thoughtsDir -Filter "thoughts_*.md" | 
    Where-Object { $_.Name -ne "thoughts_index.md" } |
    Sort-Object Name |
    ForEach-Object {
        $thoughtDate = [datetime]::ParseExact($_.BaseName.Split('_')[1], "yyyyMMdd", $null)
        $content = Get-Content $_.FullName -Raw
        $role = if ($content -match 'Aktuelle Rolle: (.+)') { $matches[1] } else { "Nicht spezifiziert" }
        $indexContent += "`n- $($thoughtDate.ToString('yyyy-MM-dd')): [$($_.Name)] | Rolle: $role"
    }
    
    $indexContent | Set-Content $indexFile -Encoding UTF8
    
    # Convert paths to relative for output
    $relativeThoughtsFile = Join-Path "dev\tasks\active" $TaskId | Join-Path -ChildPath "thoughts" | Join-Path -ChildPath (Split-Path -Leaf $thoughtsFile)
    $relativeIndexFile = Join-Path "dev\tasks\active" $TaskId | Join-Path -ChildPath "thoughts" | Join-Path -ChildPath (Split-Path -Leaf $indexFile)
    
    Write-Host "Task-Thoughts erstellt: $relativeThoughtsFile"
    Write-Host "Index aktualisiert: $relativeIndexFile"
    if ($CurrentRole -and $RoleTransitionReason) {
        Write-Host "Rollenwechsel dokumentiert: $CurrentRole ($RoleTransitionReason)"
    }
}

function Get-LatestTaskThoughts {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$TaskId
    )
    
    # Bestimme Task-Verzeichnis
    $taskDir = Join-Path $env:ACTIVE_TASKS_PATH $TaskId
    if (-not (Test-Path $taskDir)) {
        $monthDir = Join-Path $env:COMPLETED_TASKS_PATH (Get-Date).ToString('yyyy-MM')
        if (-not (Test-Path $monthDir)) {
            Write-Host "Keine Gedanken für Task $TaskId gefunden."
            return
        }
        $taskDir = Join-Path $monthDir $TaskId
    }
    
    $thoughtsDir = Join-Path $taskDir "thoughts"
    if (Test-Path $thoughtsDir) {
        $latestThought = Get-ChildItem $thoughtsDir -Filter "thoughts_*.md" |
            Where-Object { $_.Name -ne "thoughts_index.md" } |
            Sort-Object Name -Descending |
            Select-Object -First 1
        
        if ($latestThought) {
            Get-Content $latestThought.FullName -Raw
        } else {
            Write-Host "Keine Gedanken für Task $TaskId gefunden."
        }
    } else {
        Write-Host "Keine Gedanken für Task $TaskId gefunden."
    }
}

# Export der öffentlichen Funktionen
Export-ModuleMember -Function New-TaskThoughts, Get-LatestTaskThoughts
