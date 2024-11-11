# Test Coverage Analysis Script
[CmdletBinding()]
param()

# Load environment if not already loaded
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

function Get-TestCoverage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Path = $env:PROJECT_ROOT,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ExcludeDirs = @('node_modules', '.git', 'dist', 'build'),
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeDetails
    )
    
    Write-Host "Test Coverage Analysis:"
    Write-Host "---------------------"
    Write-Host ""
    
    # Initialize counters
    $stats = @{
        TotalFiles = 0
        TestedFiles = 0
        UnitTests = 0
        IntegrationTests = 0
        E2ETests = 0
        UncoveredFiles = @()
    }
    
    # Get all source files
    $sourceFiles = Get-ChildItem -Path $Path -Recurse -File |
        Where-Object {
            $exclude = $false
            foreach ($dir in $ExcludeDirs) {
                if ($_.FullName -match [regex]::Escape($dir)) {
                    $exclude = $true
                    break
                }
            }
            -not $exclude
        }
    
    foreach ($file in $sourceFiles) {
        $stats.TotalFiles++
        
        # Skip test files themselves
        if ($file.Name -match '\.test\.|\.spec\.|test_|spec_') {
            if ($file.Name -match 'e2e|end-to-end') {
                $stats.E2ETests++
            }
            elseif ($file.Name -match 'integration|int_') {
                $stats.IntegrationTests++
            }
            else {
                $stats.UnitTests++
            }
            continue
        }
        
        # Look for corresponding test files
        $baseName = $file.BaseName
        $testFiles = Get-ChildItem -Path $Path -Recurse -File |
            Where-Object {
                $_.Name -match "$baseName\.(test|spec)\." -or
                $_.Name -match "test_$baseName\." -or
                $_.Name -match "spec_$baseName\."
            }
        
        if ($testFiles) {
            $stats.TestedFiles++
        }
        else {
            $stats.UncoveredFiles += $file.FullName.Replace($Path, '').TrimStart('\')
        }
    }
    
    # Calculate coverage percentage
    $coveragePercent = if ($stats.TotalFiles -gt 0) {
        [math]::Round(($stats.TestedFiles / $stats.TotalFiles) * 100, 2)
    } else {
        0
    }
    
    # Output results
    Write-Host "Coverage Summary:"
    Write-Host "  Total Files: $($stats.TotalFiles)"
    Write-Host "  Files with Tests: $($stats.TestedFiles)"
    Write-Host "  Coverage: $($coveragePercent)%"
    Write-Host ""
    
    Write-Host "Test Types:"
    Write-Host "  Unit Tests: $($stats.UnitTests)"
    Write-Host "  Integration Tests: $($stats.IntegrationTests)"
    Write-Host "  E2E Tests: $($stats.E2ETests)"
    Write-Host ""
    
    if ($IncludeDetails -and $stats.UncoveredFiles) {
        Write-Host "Files without Tests:"
        $stats.UncoveredFiles | ForEach-Object {
            Write-Host "  $_"
        }
        Write-Host ""
    }
    
    # Check coverage thresholds
    Write-Host "Coverage Analysis:"
    if ($coveragePercent -ge 80) {
        Write-Host '  + Good coverage (>= 80%)' -ForegroundColor Green
    }
    elseif ($coveragePercent -ge 60) {
        Write-Host '  ! Moderate coverage (60-79%)' -ForegroundColor Yellow
    }
    else {
        Write-Host '  - Poor coverage (< 60%)' -ForegroundColor Red
    }
    
    if ($stats.UnitTests -eq 0) {
        Write-Host '  - No unit tests found' -ForegroundColor Red
    }
    if ($stats.IntegrationTests -eq 0) {
        Write-Host '  ! No integration tests found' -ForegroundColor Yellow
    }
    if ($stats.E2ETests -eq 0) {
        Write-Host '  ! No E2E tests found' -ForegroundColor Yellow
    }
}

# Run analysis if script is executed directly
if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    Get-TestCoverage -IncludeDetails -Verbose
}
