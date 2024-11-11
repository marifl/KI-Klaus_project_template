# Task-Listen-Skript
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('IN_PROGRESS', 'COMPLETED', 'ALL')]
    [string]$Status = 'ALL'
)

function Get-TaskStatus {
    param (
        [string]$TaskFile
    )
    
    $content = Get-Content $TaskFile -Raw
    $statusMatches = [regex]::Matches($content, '- \[x\] (\w+)')
    if ($statusMatches.Count -gt 0) {
        return $statusMatches[-1].Groups[1].Value
    }
    return "NEW"
}

function Format-TaskInfo {
    param (
        [string]$TaskId,
        [string]$Status,
        [string]$Description,
        [string]$Branch,
        [string]$LastUpdate
    )
    
    return [PSCustomObject]@{
        TaskId = $TaskId
        Status = $Status
        Description = $Description
        Branch = $Branch
        LastUpdate = $LastUpdate
    }
}

# Aktive Tasks sammeln
$tasks = @()

# Aktive Tasks durchsuchen
Get-ChildItem "dev/tasks/active" -Directory | ForEach-Object {
    $taskId = $_.Name
    $descFile = Join-Path $_.FullName "description.md"
    
    if (Test-Path $descFile) {
        $content = Get-Content $descFile -Raw
        $status = Get-TaskStatus $descFile
        $description = [regex]::Match($content, '## Beschreibung\r?\n(.+?)(\r?\n|$)').Groups[1].Value
        $branch = [regex]::Match($content, 'Branch: `(.+?)`').Groups[1].Value
        $lastUpdate = (Get-Item $descFile).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        
        if ($Status -eq 'ALL' -or $status -eq $Status) {
            $tasks += Format-TaskInfo -TaskId $taskId -Status $status -Description $description -Branch $branch -LastUpdate $lastUpdate
        }
    }
}

# Abgeschlossene Tasks durchsuchen, wenn ALL oder COMPLETED
if ($Status -eq 'ALL' -or $Status -eq 'COMPLETED') {
    Get-ChildItem "dev/tasks/completed" -Recurse -File -Filter "description.md" | ForEach-Object {
        $taskId = $_.Directory.Name
        $content = Get-Content $_.FullName -Raw
        $description = [regex]::Match($content, '## Beschreibung\r?\n(.+?)(\r?\n|$)').Groups[1].Value
        $branch = [regex]::Match($content, 'Branch: `(.+?)`').Groups[1].Value
        $lastUpdate = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        
        $tasks += Format-TaskInfo -TaskId $taskId -Status "COMPLETED" -Description $description -Branch $branch -LastUpdate $lastUpdate
    }
}

# Sortiere Tasks nach LastUpdate
$tasks = $tasks | Sort-Object LastUpdate -Descending

# Ausgabe als JSON für KI-Klaus
$tasks | ConvertTo-Json
