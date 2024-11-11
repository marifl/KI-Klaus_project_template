# Code Complexity Analysis Script
[CmdletBinding()]
param()

# Load environment if not already loaded
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

function Get-CodeComplexity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Path = $env:PROJECT_ROOT,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ExcludeDirs = @('node_modules', '.git', 'dist', 'build'),
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeDetails
    )
    
    Write-Host "Code Complexity Analysis:"
    Write-Host "----------------------"
    Write-Host ""
    
    # Initialize metrics
    $metrics = @{
        TotalFiles = 0
        TotalLines = 0
        TotalFunctions = 0
        ComplexFiles = @()
        LongFunctions = @()
        DeepNesting = @()
        LongLines = @()
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
            -not $exclude -and $_.Extension -match '\.(ps1|psm1|js|ts|py|cs|java|rb|php)$'
        }
    
    foreach ($file in $sourceFiles) {
        $metrics.TotalFiles++
        $content = Get-Content $file.FullName
        $metrics.TotalLines += $content.Count
        
        # Track long lines
        $longLines = $content | Where-Object { $_.Length -gt 120 }
        if ($longLines) {
            $metrics.LongLines += @{
                File = $file.FullName.Replace($Path, '').TrimStart('\')
                Count = $longLines.Count
                Lines = $longLines | Select-Object -First 5
            }
        }
        
        # Analyze functions/methods
        $functionMatches = $content | Select-String -Pattern '(function\s+\w+|def\s+\w+|\w+\s*=\s*function|\w+\s*:\s*function)'
        $metrics.TotalFunctions += $functionMatches.Count
        
        # Track complex functions (high line count)
        $inFunction = $false
        $functionLines = 0
        $currentFunction = ''
        $braceCount = 0
        
        for ($i = 0; $i -lt $content.Count; $i++) {
            $line = $content[$i]
            
            # Function detection based on language
            if ($line -match '(function\s+(\w+)|def\s+(\w+)|\w+\s*=\s*function|\w+\s*:\s*function)') {
                $inFunction = $true
                $functionLines = 1
                $currentFunction = if ($matches[2]) { $matches[2] } elseif ($matches[3]) { $matches[3] } else { "Anonymous" }
                $braceCount = 0
            }
            
            if ($inFunction) {
                # Count braces for nesting depth
                $braceCount += ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                $braceCount -= ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                
                if ($braceCount -gt 3) {
                    $metrics.DeepNesting += @{
                        File = $file.FullName.Replace($Path, '').TrimStart('\')
                        Function = $currentFunction
                        Depth = $braceCount
                        Line = $i + 1
                    }
                }
                
                $functionLines++
                
                # Function end detection
                if (($line -match '^}' -and $braceCount -eq 0) -or 
                    ($file.Extension -eq '.py' -and [string]::IsNullOrWhiteSpace($line) -and $i -lt ($content.Count - 1) -and -not [string]::IsNullOrWhiteSpace($content[$i + 1]))) {
                    $inFunction = $false
                    if ($functionLines -gt 50) {
                        $metrics.LongFunctions += @{
                            File = $file.FullName.Replace($Path, '').TrimStart('\')
                            Function = $currentFunction
                            Lines = $functionLines
                        }
                    }
                }
            }
        }
        
        # Track complex files (high line count or many functions)
        if ($content.Count -gt 500 -or $functionMatches.Count -gt 20) {
            $metrics.ComplexFiles += @{
                File = $file.FullName.Replace($Path, '').TrimStart('\')
                Lines = $content.Count
                Functions = $functionMatches.Count
            }
        }
    }
    
    # Output results
    Write-Host "General Metrics:"
    Write-Host "  Total Files: $($metrics.TotalFiles)"
    Write-Host "  Total Lines: $($metrics.TotalLines)"
    Write-Host "  Total Functions: $($metrics.TotalFunctions)"
    Write-Host ""
    
    if ($metrics.ComplexFiles) {
        Write-Host "Complex Files:" -ForegroundColor Yellow
        $metrics.ComplexFiles | ForEach-Object {
            Write-Host "  $($_.File)" -ForegroundColor Yellow
            Write-Host "    Lines: $($_.Lines), Functions: $($_.Functions)"
        }
        Write-Host ""
    }
    
    if ($IncludeDetails) {
        if ($metrics.LongFunctions) {
            Write-Host "Long Functions (> 50 lines):" -ForegroundColor Yellow
            $metrics.LongFunctions | ForEach-Object {
                Write-Host "  $($_.File) : $($_.Function)" -ForegroundColor Yellow
                Write-Host "    Lines: $($_.Lines)"
            }
            Write-Host ""
        }
        
        if ($metrics.DeepNesting) {
            Write-Host "Deep Nesting (> 3 levels):" -ForegroundColor Yellow
            $metrics.DeepNesting | ForEach-Object {
                Write-Host "  $($_.File) : $($_.Function)" -ForegroundColor Yellow
                Write-Host "    Depth: $($_.Depth) at line $($_.Line)"
            }
            Write-Host ""
        }
        
        if ($metrics.LongLines) {
            Write-Host "Long Lines (> 120 characters):" -ForegroundColor Yellow
            $metrics.LongLines | ForEach-Object {
                Write-Host "  $($_.File)" -ForegroundColor Yellow
                Write-Host "    Count: $($_.Count)"
                if ($IncludeDetails) {
                    Write-Host "    Examples:"
                    $_.Lines | ForEach-Object {
                        Write-Host "      $($_.Substring(0, [Math]::Min(120, $_.Length)))..."
                    }
                }
            }
            Write-Host ""
        }
    }
    
    # Analysis summary
    Write-Host "Code Quality Analysis:"
    if ($metrics.ComplexFiles.Count -eq 0) {
        Write-Host '  + No overly complex files' -ForegroundColor Green
    } else {
        Write-Host "  - Found $($metrics.ComplexFiles.Count) complex files" -ForegroundColor Yellow
    }
    
    if ($metrics.LongFunctions.Count -eq 0) {
        Write-Host '  + No overly long functions' -ForegroundColor Green
    } else {
        Write-Host "  - Found $($metrics.LongFunctions.Count) long functions" -ForegroundColor Yellow
    }
    
    if ($metrics.DeepNesting.Count -eq 0) {
        Write-Host '  + No deep nesting issues' -ForegroundColor Green
    } else {
        Write-Host "  - Found $($metrics.DeepNesting.Count) instances of deep nesting" -ForegroundColor Yellow
    }
    
    $avgLinesPerFile = [math]::Round($metrics.TotalLines / $metrics.TotalFiles, 2)
    if ($avgLinesPerFile -lt 300) {
        Write-Host "  + Good average file length ($avgLinesPerFile lines)" -ForegroundColor Green
    } else {
        Write-Host "  - High average file length ($avgLinesPerFile lines)" -ForegroundColor Yellow
    }
}

# Run analysis if script is executed directly
if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    Get-CodeComplexity -IncludeDetails -Verbose
}
