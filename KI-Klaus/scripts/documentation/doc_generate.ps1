# Dokumentations-Generator-Skript
param (
    [Parameter(Mandatory=$true)]
    [ValidateSet('module', 'api', 'setup')]
    [string]$Type,
    
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [Parameter(Mandatory=$false)]
    [string]$Path = "docs"
)

function Get-ModuleTemplate {
    param (
        [string]$ModuleName
    )
    
    return @"
# Modul: $ModuleName

## Übersicht
[Kurze Beschreibung des Moduls]

## Funktionalität
- [Hauptfunktion 1]
- [Hauptfunktion 2]
- [Hauptfunktion 3]

## Schnittstellen
### Eingabe
- [Eingabeparameter 1]
- [Eingabeparameter 2]

### Ausgabe
- [Ausgabeparameter 1]
- [Ausgabeparameter 2]

## Abhängigkeiten
- [Abhängigkeit 1]
- [Abhängigkeit 2]

## Beispiele
\`\`\`javascript
// Beispielcode hier
\`\`\`

## Tests
- [Testfall 1]
- [Testfall 2]

## Bekannte Einschränkungen
- [Einschränkung 1]
- [Einschränkung 2]

## Changelog
- [Version] - [Änderungen]
"@
}

function Get-ApiTemplate {
    param (
        [string]$ApiName
    )
    
    return @"
# API: $ApiName

## Endpunkte

### GET /api/[resource]
#### Beschreibung
[Beschreibung des Endpunkts]

#### Parameter
| Name | Typ | Erforderlich | Beschreibung |
|------|-----|--------------|--------------|
| [param1] | string | ja | [Beschreibung] |
| [param2] | number | nein | [Beschreibung] |

#### Antwort
\`\`\`json
{
    "status": "success",
    "data": {
        // Beispieldaten
    }
}
\`\`\`

### POST /api/[resource]
[...]

## Authentifizierung
- [Auth-Methode]
- [Erforderliche Header]

## Fehlerbehandlung
| Code | Bedeutung |
|------|-----------|
| 400 | [Beschreibung] |
| 401 | [Beschreibung] |
| 404 | [Beschreibung] |

## Ratenlimits
- [Limit-Beschreibung]

## Beispiele
\`\`\`curl
curl -X GET 'https://api.example.com/...'
\`\`\`
"@
}

function Get-SetupTemplate {
    param (
        [string]$ProjectName
    )
    
    return @"
# Setup: $ProjectName

## Voraussetzungen
- [Voraussetzung 1]
- [Voraussetzung 2]

## Installation
1. [Schritt 1]
2. [Schritt 2]
3. [Schritt 3]

## Konfiguration
1. [Konfigurationsschritt 1]
2. [Konfigurationsschritt 2]

## Umgebungsvariablen
| Variable | Beschreibung | Standard |
|----------|--------------|----------|
| [VAR1] | [Beschreibung] | [Wert] |
| [VAR2] | [Beschreibung] | [Wert] |

## Start
\`\`\`bash
# Startbefehl
\`\`\`

## Tests ausführen
\`\`\`bash
# Testbefehl
\`\`\`

## Troubleshooting
### Problem 1
[Lösung 1]

### Problem 2
[Lösung 2]

## Deployment
1. [Deployment-Schritt 1]
2. [Deployment-Schritt 2]
"@
}

# Hauptlogik
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$docPath = Join-Path $Path $Type
$fileName = "$($Name -replace '[^a-zA-Z0-9]','-').md"
$fullPath = Join-Path $docPath $fileName

# Verzeichnis erstellen
New-Item -ItemType Directory -Path $docPath -Force | Out-Null

# Template basierend auf Typ auswählen
$content = switch ($Type) {
    "module" { Get-ModuleTemplate -ModuleName $Name }
    "api" { Get-ApiTemplate -ApiName $Name }
    "setup" { Get-SetupTemplate -ProjectName $Name }
}

# Datei erstellen
$content | Set-Content $fullPath

# Index aktualisieren
$indexPath = Join-Path $Path "index.md"
if (-not (Test-Path $indexPath)) {
    "# Dokumentations-Index`n" | Set-Content $indexPath
}

$indexContent = Get-Content $indexPath
$newEntry = "- [$Type/$Name]($Type/$fileName)"
if ($indexContent -notcontains $newEntry) {
    Add-Content $indexPath "`n$newEntry"
}

# Ergebnis ausgeben
@{
    Type = $Type
    Name = $Name
    Path = $fullPath
    Index = $indexPath
    Timestamp = $timestamp
} | ConvertTo-Json
