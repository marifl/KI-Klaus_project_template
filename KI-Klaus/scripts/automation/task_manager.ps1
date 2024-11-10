# Task Management Script für Windows PowerShell

# Funktion zum Generieren einer Task-ID
function New-TaskId {
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    return "TASK-$timestamp"
}

# Funktion zum Erstellen eines neuen Tasks
function New-Task {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Description,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('feature', 'bugfix', 'refactor', 'docs')]
        [string]$Type,
        
        [Parameter(Mandatory=$false)]
        [string]$TaskId = (New-TaskId)
    )
    
    Write-Host "Creating new task: $TaskId"
    
    # Erstelle Task-Verzeichnis
    $taskDir = "dev/tasks/active/$TaskId"
    New-Item -ItemType Directory -Path $taskDir -Force
    
    # Lese Task-Template
    $template = Get-Content "KI-Klaus/templates/tasks/task_template.md" -Raw
    
    # Ersetze Platzhalter
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $branchName = "$Type/$TaskId-$(($Description -replace '[^a-zA-Z0-9]','-').ToLower())"
    
    $content = $template `
        -replace '\{TASK_ID\}', $TaskId `
        -replace '\{TIMESTAMP\}', $timestamp `
        -replace '\{BRANCH_NAME\}', $branchName `
        -replace '\{TASK_TYPE\}', $Type `
        -replace '\{DESCRIPTION\}', $Description
    
    # Speichere Task-Datei
    $content | Set-Content "$taskDir/description.md"
    
    # Erstelle Git-Branch
    git checkout develop
    git checkout -b $branchName
    
    Write-Host "Task created successfully: $TaskId"
    Write-Host "Branch created: $branchName"
    
    return $TaskId
}

# Funktion zum Aktualisieren des Task-Status
function Update-TaskStatus {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('NEW', 'IN_PROGRESS', 'REVIEW', 'TESTING', 'COMPLETED')]
        [string]$Status
    )
    
    Write-Host "Updating status for task: $TaskId to $Status"
    
    $taskFile = "dev/tasks/active/$TaskId/description.md"
    
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
        
        # Füge Update-Eintrag hinzu
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $content += "`n- $timestamp`: Status updated to $Status"
        
        # Speichere aktualisierte Datei
        $content | Set-Content $taskFile
        
        # Wenn Status COMPLETED ist, verschiebe in completed Ordner
        if ($Status -eq 'COMPLETED') {
            $monthDir = "dev/tasks/completed/$((Get-Date).ToString('yyyy-MM'))"
            New-Item -ItemType Directory -Path $monthDir -Force
            Move-Item $taskFile $monthDir
            Remove-Item "dev/tasks/active/$TaskId" -Recurse
        }
        
        Write-Host "Task status updated successfully"
    } else {
        Write-Host "Task file not found: $taskFile"
    }
}

# Funktion zum Auflisten aktiver Tasks
function Get-ActiveTasks {
    Write-Host "Active Tasks:"
    Write-Host "-------------"
    
    Get-ChildItem "dev/tasks/active" -Directory | ForEach-Object {
        $taskId = $_.Name
        $taskFile = Join-Path $_.FullName "description.md"
        
        if (Test-Path $taskFile) {
            $content = Get-Content $taskFile
            $description = $content | Where-Object { $_ -match '^## Beschreibung' } | Select-Object -Skip 1 -First 1
            $status = $content | Where-Object { $_ -match '- \[x\] (\w+)' } | ForEach-Object { $matches[1] }
            
            Write-Host "$taskId - $status"
            Write-Host "  $description"
            Write-Host ""
        }
    }
}

# Exportiere Funktionen
Export-ModuleMember -Function New-Task, Update-TaskStatus, Get-ActiveTasks
