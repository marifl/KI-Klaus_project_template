# Script-Finder für KI-Klaus
function Find-KIKlausScript {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Purpose,
        
        [Parameter(Mandatory=$false)]
        [string]$Category,
        
        [Parameter(Mandatory=$false)]
        [string]$Pattern,
        
        [Parameter(Mandatory=$false)]
        [switch]$TokenEfficient,
        
        [Parameter(Mandatory=$false)]
        [switch]$JsonOutput,

        [Parameter(Mandatory=$false)]
        [string]$Role,

        [Parameter(Mandatory=$false)]
        [switch]$QualityCriteria
    )

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # Registry laden
    $scriptRoot = $PSScriptRoot
    $kiKlausRoot = Split-Path -Parent $scriptRoot
    $registryPath = Join-Path $scriptRoot "core\registry.json"
    
    if (-not (Test-Path $registryPath)) {
        Write-Warning "Registry not found at: $registryPath"
        return
    }

    $registry = Get-Content $registryPath -Encoding UTF8 | ConvertFrom-Json

    function Find-ScriptsByPurpose {
        param (
            [string]$SearchPurpose,
            [string]$CurrentRole
        )
        
        $results = @()
        
        foreach ($category in $registry.categories.PSObject.Properties) {
            foreach ($script in $category.Value.scripts.PSObject.Properties) {
                if ($script.Value.purpose -like "*$SearchPurpose*" -or 
                    $script.Value.when_to_use -like "*$SearchPurpose*") {
                    
                    # Prüfe Rollen-Spezifische Patterns
                    $isRoleSpecific = $false
                    if ($CurrentRole -and $registry.common_patterns.quality_check.role_specific.$CurrentRole) {
                        $roleScripts = $registry.common_patterns.quality_check.role_specific.$CurrentRole
                        $isRoleSpecific = $roleScripts | Where-Object { $_.script -eq $script.Name }
                    }

                    $results += @{
                        Name = $script.Name
                        Category = $category.Name
                        Path = Join-Path $registry.paths.scripts $script.Value.path
                        Purpose = $script.Value.purpose
                        WhenToUse = $script.Value.when_to_use
                        TokenEfficient = $script.Value.token_efficient
                        Documentation = Join-Path $registry.paths.base $script.Value.doc
                        RoleSpecific = if ($isRoleSpecific) { $isRoleSpecific } else { $null }
                    }
                }
            }
        }
        
        return $results
    }

    function Find-ScriptsByCategory {
        param (
            [string]$SearchCategory
        )
        
        if ($registry.categories.$SearchCategory) {
            $results = @()
            foreach ($script in $registry.categories.$SearchCategory.scripts.PSObject.Properties) {
                $results += @{
                    Name = $script.Name
                    Path = Join-Path $registry.paths.scripts $script.Value.path
                    Purpose = $script.Value.purpose
                    WhenToUse = $script.Value.when_to_use
                    TokenEfficient = $script.Value.token_efficient
                    Documentation = Join-Path $registry.paths.base $script.Value.doc
                }
            }
            return $results
        }
        return $null
    }

    function Find-CommonPattern {
        param (
            [string]$SearchPattern,
            [string]$CurrentRole
        )
        
        if ($registry.common_patterns.$SearchPattern) {
            $pattern = $registry.common_patterns.$SearchPattern
            
            # Füge Rollen-spezifische Schritte hinzu
            if ($CurrentRole -and $pattern.role_specific.$CurrentRole) {
                $pattern = $pattern | Add-Member -NotePropertyName "role_steps" -NotePropertyValue $pattern.role_specific.$CurrentRole -PassThru
            }
            
            return $pattern
        }
        return $null
    }

    function Get-RoleQualityCriteria {
        param (
            [string]$Role
        )
        
        if ($registry.roles.quality_criteria.$Role) {
            return @{
                Role = $Role
                Criteria = $registry.roles.quality_criteria.$Role
            }
        }
        return $null
    }

    function Get-RoleTransitions {
        param (
            [string]$CurrentRole
        )
        
        $transitions = @()
        foreach ($transition in $registry.roles.transitions.phase_changes) {
            if ($transition.from -eq $CurrentRole -or $transition.from -eq "*") {
                $transitions += $transition
            }
        }
        return $transitions
    }

    # Hauptlogik
    $result = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Query = @{
            Purpose = $Purpose
            Category = $Category
            Pattern = $Pattern
            Role = $Role
            TokenEfficient = $TokenEfficient.IsPresent
            QualityCriteria = $QualityCriteria.IsPresent
        }
        Results = @()
    }

    if ($Role) {
        # Füge Rollen-Informationen hinzu
        $result.RoleInfo = @{
            CurrentRole = $Role
            QualityCriteria = Get-RoleQualityCriteria -Role $Role
            PossibleTransitions = Get-RoleTransitions -CurrentRole $Role
        }
    }

    if ($Purpose) {
        $scripts = Find-ScriptsByPurpose -SearchPurpose $Purpose -CurrentRole $Role
        if ($TokenEfficient) {
            $scripts = $scripts | Where-Object { $_.TokenEfficient }
        }
        $result.Results += @{
            Type = "by_purpose"
            Scripts = $scripts
        }
    }

    if ($Category) {
        $scripts = Find-ScriptsByCategory -SearchCategory $Category
        if ($TokenEfficient) {
            $scripts = $scripts | Where-Object { $_.TokenEfficient }
        }
        $result.Results += @{
            Type = "by_category"
            Scripts = $scripts
        }
    }

    if ($Pattern) {
        $pattern = Find-CommonPattern -SearchPattern $Pattern -CurrentRole $Role
        $result.Results += @{
            Type = "pattern"
            Pattern = $pattern
        }
    }

    if ($QualityCriteria -and $Role) {
        $criteria = Get-RoleQualityCriteria -Role $Role
        $result.Results += @{
            Type = "quality_criteria"
            Criteria = $criteria
        }
    }

    # Ausgabe
    if ($JsonOutput) {
        $result | ConvertTo-Json -Depth 10
    } else {
        Write-Host "Script Search Results:"
        Write-Host "--------------------"
        
        if ($Role) {
            Write-Host "`nCurrent Role: $Role"
            if ($result.RoleInfo.QualityCriteria) {
                Write-Host "`nQuality Criteria:"
                foreach ($criterion in $result.RoleInfo.QualityCriteria.Criteria) {
                    Write-Host "- $criterion"
                }
            }
            if ($result.RoleInfo.PossibleTransitions) {
                Write-Host "`nPossible Role Transitions:"
                foreach ($transition in $result.RoleInfo.PossibleTransitions) {
                    Write-Host "- To: $($transition.to) (Trigger: $($transition.trigger))"
                }
            }
        }
        
        foreach ($searchResult in $result.Results) {
            Write-Host "`nSearch Type: $($searchResult.Type)"
            
            if ($searchResult.Type -eq "pattern") {
                Write-Host "Pattern: $($searchResult.Pattern.description)"
                Write-Host "Steps:"
                foreach ($step in $searchResult.Pattern.steps) {
                    Write-Host "- $($step.script): $($step.purpose)"
                }
                if ($searchResult.Pattern.role_steps) {
                    Write-Host "`nRole-Specific Steps:"
                    foreach ($step in $searchResult.Pattern.role_steps) {
                        Write-Host "- $($step.script): $($step.purpose)"
                    }
                }
            }
            elseif ($searchResult.Type -eq "quality_criteria") {
                Write-Host "Quality Criteria for $($searchResult.Criteria.Role):"
                foreach ($criterion in $searchResult.Criteria.Criteria) {
                    Write-Host "- $criterion"
                }
            }
            else {
                foreach ($script in $searchResult.Scripts) {
                    Write-Host "`nScript: $($script.Name)"
                    Write-Host "Category: $($script.Category)"
                    Write-Host "Path: $($script.Path)"
                    Write-Host "Purpose: $($script.Purpose)"
                    Write-Host "When to use:"
                    foreach ($use in $script.WhenToUse) {
                        Write-Host "- $use"
                    }
                    Write-Host "Token Efficient: $($script.TokenEfficient)"
                    Write-Host "Documentation: $($script.Documentation)"
                    if ($script.RoleSpecific) {
                        Write-Host "Role Specific: Yes"
                    }
                }
            }
        }
    }
}

# Call the function if script is run directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Find-KIKlausScript @PSBoundParameters
}
