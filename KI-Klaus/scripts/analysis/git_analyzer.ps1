# Git Analysis Script
[CmdletBinding()]
param()

# Load environment if not already loaded
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

function Get-GitAnalysis {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Path = $env:PROJECT_ROOT,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeCommits,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeBranches,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeAuthors,
        
        [Parameter(Mandatory=$false)]
        [int]$LastDays = 30
    )
    
    Push-Location $Path
    try {
        if (-not (Test-Path ".git")) {
            Write-Warning "No Git repository found at: $Path"
            return
        }
        
        Write-Host "Git Analysis Results:"
        Write-Host "-------------------"
        Write-Host ""
        
        # Get current branch
        $currentBranch = git rev-parse --abbrev-ref HEAD
        Write-Host "Current Branch: $currentBranch"
        Write-Host ""
        
        # Get active tasks from branches
        $taskBranches = git branch | Where-Object { $_ -match 'feature/TASK-\d+' }
        if ($taskBranches) {
            Write-Host "Active Task Branches:"
            $taskBranches | ForEach-Object {
                Write-Host "  $_"
            }
            Write-Host ""
        }
        
        if ($IncludeBranches) {
            Write-Host "All Branches:"
            git branch -a | ForEach-Object {
                Write-Host "  $_"
            }
            Write-Host ""
        }
        
        if ($IncludeCommits) {
            Write-Host "Recent Commits (Last $LastDays days):"
            $since = (Get-Date).AddDays(-$LastDays).ToString("yyyy-MM-dd")
            git log --since=$since --pretty=format:"%h - %an, %ar : %s" | ForEach-Object {
                Write-Host "  $_"
            }
            Write-Host ""
        }
        
        if ($IncludeAuthors) {
            Write-Host "Contributors:"
            git shortlog -sn --all | ForEach-Object {
                Write-Host "  $_"
            }
            Write-Host ""
        }
        
        # Get task-related statistics
        $taskCommits = git log --grep="TASK-" --oneline
        if ($taskCommits) {
            Write-Host "Task-Related Statistics:"
            Write-Host "  Total Task Commits: $($taskCommits.Count)"
            
            $taskIds = $taskCommits | ForEach-Object {
                if ($_ -match 'TASK-\d+') {
                    $matches[0]
                }
            } | Select-Object -Unique
            
            Write-Host "  Unique Tasks: $($taskIds.Count)"
            Write-Host ""
            
            Write-Host "Tasks by Status:"
            $taskIds | ForEach-Object {
                $taskId = $_
                $taskDir = Join-Path $env:ACTIVE_TASKS_PATH $taskId
                $completedTaskDir = Join-Path $env:COMPLETED_TASKS_PATH (Get-Date).ToString("yyyy-MM") $taskId
                
                if (Test-Path $taskDir) {
                    $status = "Active"
                } elseif (Test-Path $completedTaskDir) {
                    $status = "Completed"
                } else {
                    $status = "Unknown"
                }
                
                Write-Host "  $taskId : $status"
            }
        }
        
    } finally {
        Pop-Location
    }
}

# Run analysis if script is executed directly
if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    Get-GitAnalysis -IncludeCommits -IncludeBranches -IncludeAuthors -Verbose
}
