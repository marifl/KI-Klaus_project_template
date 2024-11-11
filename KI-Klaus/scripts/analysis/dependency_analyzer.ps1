# Dependency-Analyse-Skript für KI-Klaus
param (
    [Parameter(Mandatory=$false)]
    [string]$Path = ".",
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckUpdates,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDevDependencies,
    
    [Parameter(Mandatory=$false)]
    [switch]$JsonOutput
)

function Get-PackageJsonInfo {
    param (
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        $packageJson = Get-Content $FilePath | ConvertFrom-Json
        
        $dependencies = @{}
        if ($packageJson.dependencies) {
            $dependencies += @{
                Production = $packageJson.dependencies.PSObject.Properties | ForEach-Object {
                    @{
                        Name = $_.Name
                        Version = $_.Value
                        Type = "production"
                    }
                }
            }
        }
        
        if ($IncludeDevDependencies -and $packageJson.devDependencies) {
            $dependencies += @{
                Development = $packageJson.devDependencies.PSObject.Properties | ForEach-Object {
                    @{
                        Name = $_.Name
                        Version = $_.Value
                        Type = "development"
                    }
                }
            }
        }
        
        if ($CheckUpdates) {
            $dependencies | ForEach-Object {
                $_.Production | ForEach-Object {
                    $latestVersion = npm show $_.Name version 2>$null
                    $_.LatestVersion = $latestVersion
                    $_.UpdateAvailable = ($_.Version -ne $latestVersion)
                }
                if ($_.Development) {
                    $_.Development | ForEach-Object {
                        $latestVersion = npm show $_.Name version 2>$null
                        $_.LatestVersion = $latestVersion
                        $_.UpdateAvailable = ($_.Version -ne $latestVersion)
                    }
                }
            }
        }
        
        return $dependencies
    }
    return $null
}

function Get-RequirementsTxtInfo {
    param (
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        $requirements = Get-Content $FilePath | Where-Object { $_ -match '^[^#]' }
        $dependencies = @()
        
        foreach ($req in $requirements) {
            if ($req -match '^([^=<>~]+)([=<>~]+)(.+)$') {
                $dep = @{
                    Name = $matches[1].Trim()
                    Version = $matches[3].Trim()
                    Constraint = $matches[2].Trim()
                    Type = "python"
                }
                
                if ($CheckUpdates) {
                    $latestVersion = pip index versions $dep.Name --pre 2>$null | Select-String "Available versions:" | ForEach-Object { ($_ -split ":")[-1].Trim().Split(",")[0].Trim() }
                    $dep.LatestVersion = $latestVersion
                    $dep.UpdateAvailable = ($dep.Version -ne $latestVersion)
                }
                
                $dependencies += $dep
            }
        }
        
        return @{ Python = $dependencies }
    }
    return $null
}

function Get-GradleDependencies {
    param (
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        $buildGradle = Get-Content $FilePath
        $dependencies = @()
        
        $buildGradle | Select-String "implementation '([^']+)'" -AllMatches | ForEach-Object {
            $_.Matches | ForEach-Object {
                $dep = $_.Groups[1].Value
                if ($dep -match '^([^:]+):([^:]+):(.+)$') {
                    $dependency = @{
                        Group = $matches[1]
                        Name = $matches[2]
                        Version = $matches[3]
                        Type = "gradle"
                    }
                    
                    if ($CheckUpdates) {
                        # Hier könnte man gradle-Version-Checker implementieren
                        $dependency.UpdateAvailable = $false
                    }
                    
                    $dependencies += $dependency
                }
            }
        }
        
        return @{ Gradle = $dependencies }
    }
    return $null
}

# Hauptanalyse durchführen
$result = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Dependencies = @{}
}

# Node.js Dependencies
$packageJsonPath = Join-Path $Path "package.json"
$nodeModules = Get-PackageJsonInfo -FilePath $packageJsonPath
if ($nodeModules) {
    $result.Dependencies.Node = $nodeModules
}

# Python Dependencies
$requirementsPath = Join-Path $Path "requirements.txt"
$pythonModules = Get-RequirementsTxtInfo -FilePath $requirementsPath
if ($pythonModules) {
    $result.Dependencies.Python = $pythonModules.Python
}

# Gradle Dependencies
$gradlePath = Join-Path $Path "build.gradle"
$gradleModules = Get-GradleDependencies -FilePath $gradlePath
if ($gradleModules) {
    $result.Dependencies.Gradle = $gradleModules.Gradle
}

# Analyse der Abhängigkeiten
$result.Summary = @{
    TotalDependencies = 0
    UpdatesAvailable = 0
    Types = @{}
}

foreach ($type in $result.Dependencies.Keys) {
    $typeDeps = $result.Dependencies.$type
    $result.Summary.Types[$type] = @{
        Count = 0
        UpdatesNeeded = 0
    }
    
    if ($type -eq "Node") {
        $result.Summary.Types[$type].Count += $typeDeps.Production.Count
        $result.Summary.Types[$type].UpdatesNeeded += ($typeDeps.Production | Where-Object { $_.UpdateAvailable }).Count
        if ($IncludeDevDependencies) {
            $result.Summary.Types[$type].Count += $typeDeps.Development.Count
            $result.Summary.Types[$type].UpdatesNeeded += ($typeDeps.Development | Where-Object { $_.UpdateAvailable }).Count
        }
    } else {
        $result.Summary.Types[$type].Count += $typeDeps.Count
        $result.Summary.Types[$type].UpdatesNeeded += ($typeDeps | Where-Object { $_.UpdateAvailable }).Count
    }
    
    $result.Summary.TotalDependencies += $result.Summary.Types[$type].Count
    $result.Summary.UpdatesAvailable += $result.Summary.Types[$type].UpdatesNeeded
}

# Ausgabe
if ($JsonOutput) {
    $result | ConvertTo-Json -Depth 10
} else {
    Write-Host "Dependency Analysis Results:"
    Write-Host "-------------------------"
    Write-Host "Total Dependencies: $($result.Summary.TotalDependencies)"
    Write-Host "Updates Available: $($result.Summary.UpdatesAvailable)"
    Write-Host ""
    
    foreach ($type in $result.Summary.Types.Keys) {
        Write-Host "$type Dependencies:"
        Write-Host "  Count: $($result.Summary.Types[$type].Count)"
        Write-Host "  Updates Needed: $($result.Summary.Types[$type].UpdatesNeeded)"
        Write-Host ""
    }
    
    if ($CheckUpdates) {
        Write-Host "Available Updates:"
        foreach ($type in $result.Dependencies.Keys) {
            $deps = $result.Dependencies.$type
            if ($type -eq "Node") {
                $updates = $deps.Production | Where-Object { $_.UpdateAvailable }
                foreach ($update in $updates) {
                    Write-Host "  $($update.Name): $($update.Version) -> $($update.LatestVersion)"
                }
                if ($IncludeDevDependencies) {
                    $devUpdates = $deps.Development | Where-Object { $_.UpdateAvailable }
                    foreach ($update in $devUpdates) {
                        Write-Host "  $($update.Name) (dev): $($update.Version) -> $($update.LatestVersion)"
                    }
                }
            } else {
                $updates = $deps | Where-Object { $_.UpdateAvailable }
                foreach ($update in $updates) {
                    Write-Host "  $($update.Name): $($update.Version) -> $($update.LatestVersion)"
                }
            }
        }
    }
}
