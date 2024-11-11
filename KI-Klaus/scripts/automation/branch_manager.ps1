# Branch Manager
# Automatisiert Git-Branch-Operationen und enforced Konventionen
# Optimiert für Token-Effizienz und Git-Workflow

#Requires -Version 5.1

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('create', 'cleanup', 'list', 'validate')]
    [string]$Action = 'list',
    
    [Parameter(Mandatory=$false)]
    [string]$BranchName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('feature', 'bugfix', 'hotfix', 'release')]
    [string]$BranchType = 'feature',
    
    [Parameter(Mandatory=$false)]
    [string]$TaskId,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$JsonOutput,
    
    [Parameter(Mandatory=$false)]
    [int]$DaysOld = 30
)

# Lade Umgebungsvariablen
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

# Branch-Konventionen
$BRANCH_PATTERNS = @{
    feature = 'feature/TASK-\d{14}-[\w-]+'
    bugfix = 'bugfix/TASK-\d{14}-[\w-]+'
    hotfix = 'hotfix/TASK-\d{14}-[\w-]+'
    release = 'release/v\d+\.\d+\.\d+'
}

# Klasse für Branch-Informationen
class BranchInfo {
    [string]$Name
    [string]$Type
    [string]$TaskId
    [string]$Description
    [datetime]$LastCommit
    [bool]$IsMerged
    [string]$Author
    
    BranchInfo($name, $type, $taskId, $desc) {
        $this.Name = $name
        $this.Type = $type
        $this.TaskId = $taskId
        $this.Description = $desc
        $this.LastCommit = [datetime]::Now
        $this.IsMerged = $false
        $this.Author = ""
    }
}

# Funktion zum Validieren des Branch-Namens
function Test-BranchName {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Type
    )
    
    $pattern = $BRANCH_PATTERNS[$Type]
    return $Name -match $pattern
}

# Funktion zum Erstellen eines neuen Branches
function New-GitBranch {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Type,
        
        [Parameter(Mandatory=$true)]
        [string]$TaskId
    )
    
    # Prüfe ob Branch bereits existiert
    $existingBranch = git branch --list $Name
    if ($existingBranch -and -not $Force) {
        throw "Branch '$Name' existiert bereits. Nutze -Force zum Überschreiben."
    }
    
    # Validiere Branch-Name
    if (-not (Test-BranchName -Name $Name -Type $Type)) {
        throw "Branch-Name entspricht nicht den Konventionen für Typ '$Type'"
    }
    
    try {
        # Checkout develop als Basis
        git checkout develop
        git pull
        
        # Erstelle neuen Branch
        git checkout -b $Name
        
        # Erstelle Branch-Info
        $branchInfo = [BranchInfo]::new($Name, $Type, $TaskId, "")
        $branchInfo.Author = git config user.name
        
        return $branchInfo
    }
    catch {
        Write-Error "Fehler beim Erstellen des Branches: $_"
        git checkout develop
        throw
    }
}

# Funktion zum Auflisten aller Branches
function Get-GitBranches {
    $branches = @()
    
    git for-each-ref --format='%(refname:short)|%(committerdate:iso8601)|%(authorname)' refs/heads/ | ForEach-Object {
        $parts = $_ -split '\|'
        $name = $parts[0]
        $date = [datetime]::Parse($parts[1])
        $author = $parts[2]
        
        # Bestimme Branch-Typ
        $type = "unknown"
        foreach ($pattern in $BRANCH_PATTERNS.GetEnumerator()) {
            if ($name -match "^$($pattern.Key)/") {
                $type = $pattern.Key
                break
            }
        }
        
        # Extrahiere Task-ID wenn vorhanden
        $taskId = if ($name -match 'TASK-\d{14}') { $matches[0] } else { "" }
        
        $branchInfo = [BranchInfo]::new($name, $type, $taskId, "")
        $branchInfo.LastCommit = $date
        $branchInfo.Author = $author
        $branchInfo.IsMerged = (git branch --merged | Where-Object { $_.Trim() -eq $name }).Count -gt 0
        
        $branches += $branchInfo
    }
    
    return $branches
}

# Funktion zum Aufräumen alter Branches
function Remove-OldBranches {
    $cutoffDate = [datetime]::Now.AddDays(-$DaysOld)
    $branches = Get-GitBranches
    $removedBranches = @()
    
    foreach ($branch in $branches) {
        if ($branch.Name -notin @('main', 'master', 'develop') -and 
            $branch.LastCommit -lt $cutoffDate -and 
            $branch.IsMerged) {
            
            Write-Verbose "Lösche Branch: $($branch.Name)"
            git branch -d $branch.Name
            $removedBranches += $branch
        }
    }
    
    return $removedBranches
}

# Hauptfunktion
function Invoke-BranchManager {
    $result = @{
        Action = $Action
        Success = $false
        Data = $null
        Message = ""
    }
    
    try {
        switch ($Action) {
            'create' {
                if (-not $BranchName -or -not $TaskId) {
                    throw "BranchName und TaskId sind erforderlich für create"
                }
                $result.Data = New-GitBranch -Name $BranchName -Type $BranchType -TaskId $TaskId
                $result.Message = "Branch erfolgreich erstellt"
            }
            
            'cleanup' {
                $result.Data = Remove-OldBranches
                $result.Message = "$($result.Data.Count) Branches gelöscht"
            }
            
            'list' {
                $result.Data = Get-GitBranches
                $result.Message = "$($result.Data.Count) Branches gefunden"
            }
            
            'validate' {
                if (-not $BranchName) {
                    throw "BranchName ist erforderlich für validate"
                }
                $result.Data = Test-BranchName -Name $BranchName -Type $BranchType
                $result.Message = if ($result.Data) { "Branch-Name ist valid" } else { "Branch-Name ist invalid" }
            }
        }
        
        $result.Success = $true
    }
    catch {
        $result.Message = $_.Exception.Message
        Write-Error $result.Message
    }
    
    # Ausgabe
    if ($JsonOutput) {
        return $result | ConvertTo-Json -Depth 10
    }
    else {
        Write-Host "`nBranch Manager - $Action" -ForegroundColor Cyan
        Write-Host "--------------------------------" -ForegroundColor Cyan
        Write-Host "Status: $(if($result.Success){'Erfolg'}else{'Fehler'})"
        Write-Host "Nachricht: $($result.Message)"
        
        if ($result.Data) {
            Write-Host "`nDetails:" -ForegroundColor Yellow
            switch ($Action) {
                'list' {
                    $result.Data | Format-Table Name, Type, LastCommit, Author, IsMerged
                }
                'cleanup' {
                    $result.Data | Format-Table Name, LastCommit, Author
                }
                'create' {
                    $result.Data | Format-List Name, Type, TaskId, Author
                }
                'validate' {
                    Write-Host "Branch-Name valid: $($result.Data)"
                }
            }
        }
    }
}

# Führe Branch Manager aus
Invoke-BranchManager
