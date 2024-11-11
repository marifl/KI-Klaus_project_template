# KI-Klaus Skript-Dokumentation

## 1. Verzeichnisstruktur

```
scripts/
├── find_script.ps1          # Skript-Finder (Hauptwerkzeug für KI-Klaus)
├── register_script.ps1      # Skript-Registrierung (für Entwickler)
├── README.md               # Diese Dokumentation
│
├── core/                   # Zentrale Werkzeuge
│   └── registry.json      # Skript-Registry
│
├── automation/            # Task-Management
│   ├── task_manager.ps1  # Hauptmodul für Tasks
│   ├── task_list.ps1     # Task-Übersicht
│   └── task_thoughts_manager.ps1  # Gedanken-Dokumentation
│
├── analysis/             # Analyse-Werkzeuge
│   ├── git_analyzer.ps1           # Git-Analyse
│   ├── dependency_analyzer.ps1    # Dependency-Analyse
│   ├── test_coverage_analyzer.ps1 # Test-Coverage
│   ├── code_structure.ps1         # Code-Struktur
│   └── project_health.ps1         # Projekt-Gesundheit
│
├── setup/               # Projekt-Setup
│   ├── project_setup.ps1 # Projekt-Initialisierung
│   └── init_git.ps1      # Git-Setup
│
└── documentation/       # Dokumentation
    └── doc_generate.ps1  # Docs-Generator
```

## 2. Skript-Kategorien

### Core
Zentrale Werkzeuge für die Skript-Verwaltung:
- **registry.json**: Zentrale Datenbank aller verfügbaren Skripte

### Automation
Task-Management und Automatisierung:
- **task_manager.ps1**: Hauptmodul für Task-Verwaltung
- **task_list.ps1**: Effiziente Task-Übersicht
- **task_thoughts_manager.ps1**: Gedanken-Dokumentation

### Analysis
Code- und Projekt-Analyse:
- **git_analyzer.ps1**: Git-Repository-Analyse
- **dependency_analyzer.ps1**: Dependency-Management
- **test_coverage_analyzer.ps1**: Test-Coverage-Analyse
- **code_structure.ps1**: Code-Struktur-Analyse
- **project_health.ps1**: Projekt-Gesundheitscheck

### Setup
Projekt-Initialisierung:
- **project_setup.ps1**: Vollständiges Projekt-Setup
- **init_git.ps1**: Git-Repository-Setup

### Documentation
Dokumentations-Management:
- **doc_generate.ps1**: Automatische Dokumentations-Generierung

## 3. Skript-Entwicklung

### Skript-Struktur
Jedes Skript muss folgende Elemente enthalten:

```powershell
# Skript-Header mit Beschreibung
param (
    [Parameter(Mandatory=$true)]
    [string]$RequiredParam,
    
    [Parameter(Mandatory=$false)]
    [switch]$JsonOutput  # Für Token-Optimierung
)

# Hauptfunktionalität
function Main-Function {
    # Implementierung
}

# JSON-Ausgabe für Token-Optimierung
if ($JsonOutput) {
    $result | ConvertTo-Json -Depth 10
} else {
    # Menschenlesbare Ausgabe
}
```

### Token-Optimierung
- JSON-Output-Parameter implementieren
- Batch-Operationen bevorzugen
- Unnötige Ausgaben vermeiden
- Effiziente Datenstrukturen nutzen

### Dokumentation
Jedes Skript braucht:
- Klaren Zweck
- Parameter-Beschreibungen
- Verwendungsbeispiele
- Rückgabewerte-Dokumentation
- Fehlerbehandlung

## 4. Integration neuer Skripte

### 1. Skript erstellen
1. Passende Kategorie wählen
2. Skript-Template nutzen
3. Token-Optimierung implementieren
4. Tests schreiben

### 2. Dokumentation erstellen
1. Markdown-Datei in docs/ anlegen
2. Alle Funktionen dokumentieren
3. Beispiele hinzufügen
4. Verwandte Skripte verlinken

### 3. Skript registrieren
```powershell
# Neues Skript registrieren
.\register_script.ps1 `
    -Path "category/my_script.ps1" `
    -Category "analysis" `
    -Purpose "Beschreibung des Zwecks" `
    -WhenToUse "Anwendungsfall 1", "Anwendungsfall 2" `
    -TokenEfficient
```

### 4. Testen
1. Funktionalität prüfen
2. Token-Effizienz testen
3. JSON-Output validieren
4. Dokumentation verifizieren

## 5. Verwendung

### Skript finden (für KI-Klaus)
```powershell
# Nach Zweck suchen
.\find_script.ps1 -Purpose "Task erstellen"

# Nach Kategorie suchen
.\find_script.ps1 -Category "analysis"

# Nach Muster suchen
.\find_script.ps1 -Pattern "code_review"

# Token-effiziente Skripte finden
.\find_script.ps1 -Purpose "Analyse" -TokenEfficient
```

### Task-Management
```powershell
# Task erstellen
Import-Module .\automation\task_manager.ps1
New-Task -Description "Neue Funktion" -Type feature -JsonOutput

# Task-Status aktualisieren
Update-TaskStatus -TaskId "TASK-123" -Status "IN_PROGRESS" -JsonOutput

# Tasks auflisten
.\automation\task_list.ps1 -Status ALL
```

### Analyse
```powershell
# Git-Analyse
.\analysis\git_analyzer.ps1 -Branch "feature/xyz" -IncludeMergeInfo

# Dependency-Check
.\analysis\dependency_analyzer.ps1 -CheckUpdates -JsonOutput

# Test-Coverage
.\analysis\test_coverage_analyzer.ps1 -GenerateReport
```

### Setup
```powershell
# Neues Projekt
.\setup\project_setup.ps1 -ProjectName "MeinProjekt" -IncludeMicroservices

# Git-Setup
.\setup\init_git.ps1
```

### Dokumentation
```powershell
# API-Docs generieren
.\documentation\doc_generate.ps1 -Type api -Name "Backend"
```

## 6. Best Practices

### Allgemein
1. Klare Funktionsnamen
2. Aussagekräftige Parameter
3. Fehlerbehandlung implementieren
4. Logging einbauen

### Token-Optimierung
1. Batch-Operationen nutzen
2. Unnötige Ausgaben vermeiden
3. JSON-Strukturen optimieren
4. Caching wo sinnvoll

### Dokumentation
1. Klare Beschreibungen
2. Realistische Beispiele
3. Fehlermeldungen dokumentieren
4. Abhängigkeiten auflisten

### Integration
1. Kategorien respektieren
2. Registry aktuell halten
3. Tests durchführen
4. Feedback einarbeiten

## 7. Fehlerbehebung

### Registrierung schlägt fehl
1. Pfade überprüfen
2. Kategorie validieren
3. JSON-Syntax prüfen
4. Berechtigungen kontrollieren

### Skript funktioniert nicht
1. Parameter prüfen
2. Pfade validieren
3. Logs analysieren
4. Tests ausführen

## 8. Wartung

### Skript aktualisieren
1. Änderungen dokumentieren
2. Tests aktualisieren
3. Registry anpassen
4. Dokumentation erneuern

### Kategorie ändern
1. Skript verschieben
2. register_script.ps1 ausführen
3. Alte Einträge entfernen
4. Dokumentation aktualisieren

## 9. Support

Bei Fragen oder Problemen:
1. Dokumentation prüfen
2. Logs analysieren
3. Tests durchführen
4. Issue erstellen

## 10. Zusammenfassung
Die Skript-Sammlung ist:
- Modular aufgebaut
- Token-optimiert
- Gut dokumentiert
- Einfach erweiterbar

Befolge diese Richtlinien für konsistente und effiziente Skript-Entwicklung!
