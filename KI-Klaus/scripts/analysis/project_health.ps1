# Projekt-Gesundheits-Check-Skript

function Test-DirectoryStructure {
    $requiredDirs = @(
        "src",
        "docs",
        "tests",
        "dev/tasks/active",
        "dev/tasks/completed",
        "KI-Klaus"
    )
    
    $missingDirs = @()
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            $missingDirs += $dir
        }
    }
    
    return @{
        Status = $missingDirs.Count -eq 0
        MissingDirs = $missingDirs
    }
}

function Test-Documentation {
    $requiredDocs = @(
        "docs/projectRoadmap.md",
        "docs/techStack.md",
        "docs/codebaseSummary.md",
        "README.md"
    )
    
    $missingDocs = @()
    foreach ($doc in $requiredDocs) {
        if (-not (Test-Path $doc)) {
            $missingDocs += $doc
        }
    }
    
    return @{
        Status = $missingDocs.Count -eq 0
        MissingDocs = $missingDocs
    }
}

function Get-LargeFiles {
    $maxLines = 300
    $largeFiles = @()
    
    Get-ChildItem -Path "src" -Recurse -File | ForEach-Object {
        $lineCount = (Get-Content $_.FullName).Count
        if ($lineCount -gt $maxLines) {
            $largeFiles += @{
                Path = $_.FullName
                Lines = $lineCount
                ExcessLines = $lineCount - $maxLines
            }
        }
    }
    
    return @{
        Status = $largeFiles.Count -eq 0
        LargeFiles = $largeFiles
    }
}

function Get-TaskStatus {
    $activeTasks = (Get-ChildItem "dev/tasks/active" -Directory).Count
    $completedTasks = (Get-ChildItem "dev/tasks/completed" -Recurse -File -Filter "description.md").Count
    
    return @{
        ActiveTasks = $activeTasks
        CompletedTasks = $completedTasks
        TotalTasks = $activeTasks + $completedTasks
    }
}

function Get-GitStatus {
    $unstagedChanges = git status --porcelain
    $branches = git branch
    $lastCommit = git log -1 --format="%h - %s (%cr)"
    
    return @{
        UnstagedChanges = $unstagedChanges.Count
        BranchCount = $branches.Count
        LastCommit = $lastCommit
    }
}

function Get-TodoComments {
    $todos = @()
    
    Get-ChildItem -Path "src" -Recurse -File | ForEach-Object {
        $foundTodos = Select-String -Path $_.FullName -Pattern "(?i)TODO:"
        if ($foundTodos) {
            $todos += @{
                File = $_.FullName
                Lines = $foundTodos | ForEach-Object { $_.Line.Trim() }
            }
        }
    }
    
    return @{
        Count = $todos.Count
        Items = $todos
    }
}

# Hauptprüfung durchführen
$healthCheck = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    DirectoryStructure = Test-DirectoryStructure
    Documentation = Test-Documentation
    LargeFiles = Get-LargeFiles
    TaskStatus = Get-TaskStatus
    GitStatus = Get-GitStatus
    TodoComments = Get-TodoComments
}

# Gesamtstatus berechnen
$healthCheck.OverallStatus = @{
    IsHealthy = (
        $healthCheck.DirectoryStructure.Status -and
        $healthCheck.Documentation.Status -and
        $healthCheck.LargeFiles.Status
    )
    Warnings = @()
    Recommendations = @()
}

# Warnungen und Empfehlungen hinzufügen
if (-not $healthCheck.DirectoryStructure.Status) {
    $healthCheck.OverallStatus.Warnings += "Fehlende Verzeichnisse gefunden"
    $healthCheck.OverallStatus.Recommendations += "Erstellen Sie die fehlenden Verzeichnisse: $($healthCheck.DirectoryStructure.MissingDirs -join ', ')"
}

if (-not $healthCheck.Documentation.Status) {
    $healthCheck.OverallStatus.Warnings += "Fehlende Dokumentation"
    $healthCheck.OverallStatus.Recommendations += "Erstellen Sie die fehlende Dokumentation: $($healthCheck.Documentation.MissingDocs -join ', ')"
}

if (-not $healthCheck.LargeFiles.Status) {
    $healthCheck.OverallStatus.Warnings += "Große Dateien gefunden"
    $healthCheck.OverallStatus.Recommendations += "Refactoren Sie die großen Dateien in kleinere Module"
}

if ($healthCheck.GitStatus.UnstagedChanges -gt 0) {
    $healthCheck.OverallStatus.Warnings += "Nicht commitete Änderungen"
    $healthCheck.OverallStatus.Recommendations += "Committen Sie die ausstehenden Änderungen"
}

if ($healthCheck.TodoComments.Count -gt 0) {
    $healthCheck.OverallStatus.Warnings += "Offene TODO-Kommentare gefunden"
    $healthCheck.OverallStatus.Recommendations += "Überprüfen Sie die TODO-Kommentare und erstellen Sie entsprechende Tasks"
}

# Ausgabe als JSON für KI-Klaus
$healthCheck | ConvertTo-Json -Depth 10
