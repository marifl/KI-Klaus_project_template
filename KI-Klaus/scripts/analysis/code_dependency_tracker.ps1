# Code Dependency Tracking Script
[CmdletBinding()]
param()

# Load environment if not already loaded
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

function Get-CodeDependencies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Path = $env:PROJECT_ROOT,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ExcludeDirs = @('node_modules', '.git', 'dist', 'build'),
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeDetails
    )
    
    Write-Host "Code Dependency Analysis:"
    Write-Host "----------------------"
    Write-Host ""
    
    # Initialize dependency tracking
    $dependencies = @{
        Imports = @{}
        Exports = @{}
        ModuleRelations = @{}
        CircularDependencies = @()
        UnusedExports = @()
        MissingDependencies = @()
    }
    
    # Regular expressions for different types of imports/exports
    $patterns = @{
        PowerShell = @{
            Import = 'Import-Module\s+([''"]?)([^''"\s]+)([''"]?)'
            Export = 'Export-ModuleMember\s+-Function\s+([^;\r\n]+)'
            Function = 'function\s+([A-Za-z0-9_-]+)'
        }
        JavaScript = @{
            Import = '(import\s+.*?from\s+[''"])([^''"\s]+)([''"])|require\([''"]([^''"\s]+)[''"]\)'
            Export = 'export\s+(?:default\s+)?(?:function|class|const|let|var)\s+([A-Za-z0-9_]+)'
        }
        Python = @{
            Import = '(?:from\s+([^\s]+)\s+)?import\s+([^\s]+)'
            Export = '(?:^|\s)def\s+([A-Za-z0-9_]+)|class\s+([A-Za-z0-9_]+)'
        }
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
        $relativePath = $file.FullName.Replace($Path, '').TrimStart('\')
        $content = Get-Content $file.FullName -Raw
        
        # Determine file type and use appropriate patterns
        $filePatterns = switch -Regex ($file.Extension) {
            '\.ps(m?)1$' { $patterns.PowerShell }
            '\.(js|ts)$' { $patterns.JavaScript }
            '\.py$' { $patterns.Python }
            default { $patterns.PowerShell }
        }
        
        # Track imports
        $imports = [System.Collections.ArrayList]@()
        
        switch -Regex ($file.Extension) {
            '\.ps(m?)1$' {
                $content | Select-String -Pattern $filePatterns.Import -AllMatches | 
                    ForEach-Object { $_.Matches } | ForEach-Object {
                        $imports.Add($_.Groups[2].Value) | Out-Null
                    }
            }
            '\.(js|ts)$' {
                $content | Select-String -Pattern $filePatterns.Import -AllMatches |
                    ForEach-Object { $_.Matches } | ForEach-Object {
                        $imports.Add(($_.Groups[2].Value, $_.Groups[4].Value | Where-Object { $_ })) | Out-Null
                    }
            }
            '\.py$' {
                $content | Select-String -Pattern $filePatterns.Import -AllMatches |
                    ForEach-Object { $_.Matches } | ForEach-Object {
                        if ($_.Groups[1].Value) {
                            $imports.Add("$($_.Groups[1].Value).$($_.Groups[2].Value)") | Out-Null
                        } else {
                            $imports.Add($_.Groups[2].Value) | Out-Null
                        }
                    }
            }
        }
        
        if ($imports.Count -gt 0) {
            $dependencies.Imports[$relativePath] = $imports
        }
        
        # Track exports
        $exports = [System.Collections.ArrayList]@()
        
        $content | Select-String -Pattern $filePatterns.Export -AllMatches |
            ForEach-Object { $_.Matches } | ForEach-Object {
                $exports.Add(($_.Groups[1].Value, $_.Groups[2].Value | Where-Object { $_ })) | Out-Null
            }
        
        if ($exports.Count -gt 0) {
            $dependencies.Exports[$relativePath] = $exports
        }
        
        # Track module relations
        foreach ($import in $imports) {
            if (-not $dependencies.ModuleRelations.ContainsKey($relativePath)) {
                $dependencies.ModuleRelations[$relativePath] = @()
            }
            $dependencies.ModuleRelations[$relativePath] += $import
        }
    }
    
    # Detect circular dependencies
    $visited = @{}
    $recursionStack = @{}
    
    function Find-CircularDependencies {
        param (
            [string]$Module,
            [System.Collections.ArrayList]$Path
        )
        
        if ($recursionStack.ContainsKey($Module)) {
            $circularPath = $Path + @($Module)
            if (-not ($dependencies.CircularDependencies -contains $circularPath)) {
                $dependencies.CircularDependencies += ,$circularPath
            }
            return
        }
        
        if ($visited.ContainsKey($Module)) { return }
        
        $visited[$Module] = $true
        $recursionStack[$Module] = $true
        $Path.Add($Module) | Out-Null
        
        if ($dependencies.ModuleRelations.ContainsKey($Module)) {
            foreach ($dependency in $dependencies.ModuleRelations[$Module]) {
                Find-CircularDependencies -Module $dependency -Path $Path
            }
        }
        
        $recursionStack.Remove($Module)
        $Path.RemoveAt($Path.Count - 1)
    }
    
    foreach ($module in $dependencies.ModuleRelations.Keys) {
        Find-CircularDependencies -Module $module -Path ([System.Collections.ArrayList]@())
    }
    
    # Find unused exports
    foreach ($file in $dependencies.Exports.Keys) {
        foreach ($export in $dependencies.Exports[$file]) {
            $used = $false
            foreach ($imports in $dependencies.Imports.Values) {
                if ($imports -contains $export) {
                    $used = $true
                    break
                }
            }
            if (-not $used) {
                $dependencies.UnusedExports += @{
                    File = $file
                    Export = $export
                }
            }
        }
    }
    
    # Find missing dependencies
    foreach ($file in $dependencies.Imports.Keys) {
        foreach ($import in $dependencies.Imports[$file]) {
            $found = $false
            foreach ($exports in $dependencies.Exports.Values) {
                if ($exports -contains $import) {
                    $found = $true
                    break
                }
            }
            if (-not $found -and -not ($import -match '^\w+$')) {  # Skip built-in modules
                $dependencies.MissingDependencies += @{
                    File = $file
                    Import = $import
                }
            }
        }
    }
    
    # Output results
    Write-Host "Module Statistics:"
    Write-Host "  Files with Imports: $($dependencies.Imports.Count)"
    Write-Host "  Files with Exports: $($dependencies.Exports.Count)"
    Write-Host "  Module Relations: $($dependencies.ModuleRelations.Count)"
    Write-Host ""
    
    if ($dependencies.CircularDependencies) {
        Write-Host "Circular Dependencies:" -ForegroundColor Yellow
        foreach ($circle in $dependencies.CircularDependencies) {
            Write-Host "  $($circle -join ' -> ')" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    if ($IncludeDetails) {
        if ($dependencies.UnusedExports) {
            Write-Host "Unused Exports:" -ForegroundColor Yellow
            foreach ($unused in $dependencies.UnusedExports) {
                Write-Host "  $($unused.File): $($unused.Export)" -ForegroundColor Yellow
            }
            Write-Host ""
        }
        
        if ($dependencies.MissingDependencies) {
            Write-Host "Missing Dependencies:" -ForegroundColor Red
            foreach ($missing in $dependencies.MissingDependencies) {
                Write-Host "  $($missing.File) requires: $($missing.Import)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        Write-Host "Module Dependencies:"
        foreach ($module in $dependencies.ModuleRelations.Keys | Sort-Object) {
            Write-Host "  $module"
            foreach ($dependency in $dependencies.ModuleRelations[$module]) {
                Write-Host "    -> $dependency"
            }
        }
    }
    
    # Analysis summary
    Write-Host "Dependency Analysis:"
    if ($dependencies.CircularDependencies.Count -eq 0) {
        Write-Host '  + No circular dependencies' -ForegroundColor Green
    } else {
        Write-Host "  - Found $($dependencies.CircularDependencies.Count) circular dependencies" -ForegroundColor Yellow
    }
    
    if ($dependencies.UnusedExports.Count -eq 0) {
        Write-Host '  + No unused exports' -ForegroundColor Green
    } else {
        Write-Host "  - Found $($dependencies.UnusedExports.Count) unused exports" -ForegroundColor Yellow
    }
    
    if ($dependencies.MissingDependencies.Count -eq 0) {
        Write-Host '  + No missing dependencies' -ForegroundColor Green
    } else {
        Write-Host "  - Found $($dependencies.MissingDependencies.Count) missing dependencies" -ForegroundColor Red
    }
}

# Run analysis if script is executed directly
if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    Get-CodeDependencies -IncludeDetails -Verbose
}
