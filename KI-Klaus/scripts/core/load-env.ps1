# Environment Loader für KI-Klaus
# Lädt Umgebungsvariablen aus .env und stellt sie systemweit zur Verfügung

function Initialize-KIKlausEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$EnvFile = ".env",
        
        [Parameter(Mandatory=$false)]
        [switch]$Force,
        
        [Parameter(Mandatory=$false)]
        [switch]$ValidateOnly
    )
    
    try {
        # Bestimme Projekt-Root (2 Verzeichnisse über diesem Skript)
        $projectRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        $envPath = Join-Path $projectRoot "KI-Klaus" $EnvFile
        
        Write-Verbose "Suche .env Datei in: $envPath"
        
        if (-not (Test-Path $envPath)) {
            # Wenn .env nicht existiert, kopiere .env.example
            $envExamplePath = Join-Path $projectRoot "KI-Klaus" ".env.example"
            if (Test-Path $envExamplePath) {
                Write-Warning "Keine .env Datei gefunden. Kopiere .env.example zu .env"
                Copy-Item $envExamplePath $envPath
            } else {
                throw "Weder .env noch .env.example gefunden in $projectRoot/KI-Klaus"
            }
        }
        
        # Lade und validiere Umgebungsvariablen
        $envContent = Get-Content $envPath -ErrorAction Stop
        $envVars = @{}
        $currentLine = 0
        $requiredVars = @(
            'PROJECT_ROOT_PATH',
            'ACTIVE_TASKS_PATH',
            'TASK_TEMPLATES_PATH',
            'SCRIPTS_CORE_PATH'
        )
        
        foreach ($line in $envContent) {
            $currentLine++
            
            # Überspringe Kommentare und leere Zeilen
            if ($line.Trim() -match '^#' -or $line.Trim() -eq '') {
                continue
            }
            
            # Parse Variable
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim('"').Trim("'").Trim()
                
                # Ersetze ${VAR} Referenzen
                while ($value -match '\${([^}]+)}') {
                    $varName = $matches[1]
                    if ($envVars.ContainsKey($varName)) {
                        $value = $value -replace "\`${$varName}", $envVars[$varName]
                    } else {
                        $existingValue = [Environment]::GetEnvironmentVariable($varName)
                        if ($existingValue) {
                            $value = $value -replace "\`${$varName}", $existingValue
                        } else {
                            Write-Warning ("Variable nicht gefunden: " + $varName + " in Zeile " + $currentLine)
                            break
                        }
                    }
                }
                
                $envVars[$key] = $value
            } else {
                Write-Warning ("Ungültiges Format in Zeile " + $currentLine + ": " + $line)
            }
        }
        
        # Validiere erforderliche Variablen
        $missingVars = $requiredVars | Where-Object { -not $envVars.ContainsKey($_) }
        if ($missingVars) {
            throw ("Fehlende erforderliche Variablen: " + ($missingVars -join ', '))
        }
        
        # Validiere Pfade
        $pathVars = $envVars.Keys | Where-Object { $_ -like '*_PATH' }
        foreach ($currentVar in $pathVars) {
            $path = $envVars[$currentVar]
            if (-not (Test-Path $path) -and -not $ValidateOnly) {
                Write-Verbose ("Erstelle Verzeichnis für " + $currentVar + ": " + $path)
                try {
                    New-Item -Path $path -ItemType Directory -Force | Out-Null
                } catch {
                    Write-Warning ("Konnte Verzeichnis nicht erstellen: " + $path)
                }
            }
        }
        
        if ($ValidateOnly) {
            return $envVars
        }
        
        # Setze Umgebungsvariablen
        foreach ($currentKey in $envVars.Keys) {
            $value = $envVars[$currentKey]
            
            # Prüfe ob Variable bereits existiert
            $existingValue = [Environment]::GetEnvironmentVariable($currentKey)
            if ($existingValue -and -not $Force) {
                Write-Verbose ("Variable existiert bereits: " + $currentKey)
                continue
            }
            
            # Setze Variable
            [Environment]::SetEnvironmentVariable($currentKey, $value, 'Process')
            Write-Verbose ("Variable gesetzt: " + $currentKey + " = " + $value)
        }
        
        # Erstelle Zusammenfassung
        $summary = @{
            LoadedVariables = $envVars.Count
            CreatedPaths = ($pathVars | Where-Object { Test-Path $envVars[$_] }).Count
            MissingPaths = ($pathVars | Where-Object { -not (Test-Path $envVars[$_]) }).Count
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        # Speichere Zusammenfassung
        $summaryPath = Join-Path $projectRoot "KI-Klaus/logs/env_summary.json"
        $summaryDir = Split-Path $summaryPath
        if (-not (Test-Path $summaryDir)) {
            New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
        }
        $summary | ConvertTo-Json | Set-Content $summaryPath -Encoding UTF8
        
        Write-Verbose ("Umgebungsvariablen erfolgreich geladen: " + $envVars.Count + " Variablen")
        return $summary
        
    } catch {
        Write-Error ("Fehler beim Laden der Umgebungsvariablen: " + $_)
        throw
    }
}

# Exportiere Funktionen
Export-ModuleMember -Function Initialize-KIKlausEnvironment

# Wenn direkt ausgeführt, initialisiere Umgebung
if ($MyInvocation.InvocationName -eq '.') {
    Initialize-KIKlausEnvironment -Verbose
}
