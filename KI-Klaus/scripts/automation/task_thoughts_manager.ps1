# Task Thoughts Manager Skript mit Modul-Kompatibilität
# Versucht das ThoughtManager-Modul zu nutzen, fällt auf Legacy-Code zurück wenn nicht verfügbar

# Prüfe ob das Modul verfügbar ist
$useModule = $false
try {
    $modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\KI-Klaus\ThoughtManager"
    if (Test-Path $modulePath) {
        Import-Module ThoughtManager -ErrorAction Stop
        $useModule = $true
        Write-Verbose "ThoughtManager Modul geladen"
    }
} catch {
    Write-Verbose "ThoughtManager Modul nicht verfügbar, nutze Legacy-Code"
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
    Export-ModuleMember -Function New-TaskThoughts, Get-LatestTaskThoughts
} else {
    # Legacy-Code - Original Implementierung
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
        
        $taskDir = "dev/tasks/active/$TaskId"
        if (-not (Test-Path $taskDir)) {
            $taskDir = "dev/tasks/completed/$((Get-Date).ToString('yyyy-MM'))"
            if (-not (Test-Path $taskDir)) {
                New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
            }
            $taskDir = "$taskDir/$TaskId"
        }
        
        # Erstelle thoughts Verzeichnis
        $thoughtsDir = "$taskDir/thoughts"
        New-Item -ItemType Directory -Path $thoughtsDir -Force | Out-Null
        
        # Generiere Timestamp für den Dateinamen
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $thoughtsFile = "$thoughtsDir/thoughts_$timestamp.md"
        
        # Lese Template
        $template = Get-Content "KI-Klaus/templates/tasks/task_thoughts_template.md" -Raw
        
        # Hole aktuellen Task-Status
        $taskContent = Get-Content "$taskDir/description.md" -Raw
        $status = if ($taskContent -match '- \[x\] (\w+)') { $matches[1] } else { "NEW" }
        
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
        $content = $content -replace '1\. \{NEXT_STEP_1\}\s*2\. \{NEXT_STEP_2\}\s*3\. \{NEXT_STEP_3\}', $nextStepsText
        
        # Füge Open Questions hinzu
        if ($OpenQuestions) {
            $questionsText = ($OpenQuestions | ForEach-Object { "- $_" }) -join "`n"
            $content = $content -replace '- \{OPEN_QUESTION_1\}\s*- \{OPEN_QUESTION_2\}', $questionsText
        }
        
        # Füge Relevant Files hinzu
        if ($RelevantFiles) {
            $filesText = ($RelevantFiles | ForEach-Object { "  - $_" }) -join "`n"
            $content = $content -replace '  - \{FILE_1\}\s*  - \{FILE_2\}', $filesText
        }
        
        # Füge Actions hinzu
        if ($LastAction) {
            $content = $content -replace '\{LAST_ACTION\}', $LastAction
        }
        if ($PlannedAction) {
            $content = $content -replace '\{PLANNED_ACTION\}', $PlannedAction
        }
        
        # Füge Technical Details hinzu
        if ($TechnicalDetails) {
            $content = $content -replace '\{TECHNICAL_DETAILS\}', $TechnicalDetails
        }
        
        # Schreibe Datei
        $content | Set-Content $thoughtsFile -Encoding UTF8
        
        # Erstelle/Aktualisiere thoughts_index.md
        $indexFile = "$thoughtsDir/thoughts_index.md"
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
        
        Write-Host "Task-Thoughts erstellt: $thoughtsFile"
        Write-Host "Index aktualisiert: $indexFile"
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
        
        $taskDir = "dev/tasks/active/$TaskId"
        if (-not (Test-Path $taskDir)) {
            $taskDir = "dev/tasks/completed/$((Get-Date).ToString('yyyy-MM'))"
            if (-not (Test-Path $taskDir)) {
                Write-Host "Keine Gedanken für Task $TaskId gefunden."
                return
            }
            $taskDir = "$taskDir/$TaskId"
        }
        
        $thoughtsDir = "$taskDir/thoughts"
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
}

# Export der Funktionen
if ($MyInvocation.InvocationName -ne '.') {
    Export-ModuleMember -Function New-TaskThoughts, Get-LatestTaskThoughts
}
