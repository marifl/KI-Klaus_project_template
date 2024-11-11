# KI-Klaus Projekt-Template

## Übersicht
Dieses Repository ist ein Template für neue Softwareprojekte mit integrierter KI-Unterstützung durch KI-Klaus. Es bietet eine standardisierte Projektstruktur, automatisiertes Task-Management und Git-Integration.

## Features

### 1. Git-Integration
- Automatisierte Task-Verwaltung über Git-Hooks
- Standardisierte Commit-Message-Templates
- Branch-Management-Strategie
- Automatische Status-Updates

### 2. Task-Management
- Strukturierte Task-Verwaltung in `dev/tasks/`
- Automatische Status-Verfolgung
- Task-Archivierung
- Integrierte Dokumentation

### 3. KI-Klaus Integration
- Vordefinierte KI-Rollen für verschiedene Entwicklungsphasen
- Automatisierte Entwicklungsunterstützung
- Integrierte Dokumentationsvorlagen
- Workflow-Optimierung

## Verzeichnisstruktur
```
project-root/
├── .git/                    # Git-Repository
├── dev/
│   └── tasks/              # Task-Management
│       ├── active/         # Aktive Tasks
│       └── completed/      # Abgeschlossene Tasks
├── docs/                   # Projektdokumentation
├── KI-Klaus/              # KI-Assistent Konfiguration
│   ├── roles/             # Rollendefinitionen
│   ├── templates/         # Templates
│   └── scripts/          # Automatisierungsskripte
└── src/                   # Projektquellcode
```

## Setup für neue Projekte

### 1. Voraussetzungen
- Git installiert
- PowerShell 5.1 oder höher
- Entwicklungsumgebung (z.B. VS Code)

### 2. Initialisierung
1. Repository klonen:
   ```powershell
   git clone <template-url> <projekt-name>
   cd <projekt-name>
   ```

2. Git-Setup ausführen:
   ```powershell
   .\KI-Klaus\scripts\setup\init_git.ps1
   ```

3. Projekt-spezifische Konfiguration:
   - README.md anpassen
   - .gitignore aktualisieren
   - Projektabhängigkeiten einrichten

### 3. Ersten Task erstellen
```powershell
Import-Module .\KI-Klaus\scripts\automation\task_manager.ps1
New-Task -Description "Projekt-Setup abschließen" -Type feature
```

## Workflow

### 1. Task-Management
- Tasks werden in `dev/tasks/active/` erstellt
- Status-Updates erfolgen über Commit-Messages
- Abgeschlossene Tasks werden automatisch archiviert

### 2. Git-Workflow
- Feature-Branches: `feature/TASK-ID-beschreibung`
- Commit-Message-Format:
  ```
  [TASK-ID] Typ: Kurze Beschreibung

  - Detaillierte Beschreibung
  - Weitere Informationen

  Task: #TASK-ID
  Status: [IN_PROGRESS|COMPLETED|TESTING]
  ```

### 3. KI-Klaus Nutzung
- Dokumentation in `KI-Klaus/roles/` für verschiedene Entwicklungsrollen
- Automatisierte Unterstützung durch KI-Klaus
- Integrierte Entwicklungsprozesse

## Best Practices

### 1. Task-Erstellung
- Klare, aussagekräftige Beschreibungen
- Definierte Akzeptanzkriterien
- Angemessene Task-Größe

### 2. Code-Management
- Regelmäßige kleine Commits
- Aussagekräftige Commit-Messages
- Code-Review-Prozess einhalten

### 3. Dokumentation
- Dokumentation parallel zur Entwicklung
- Klare Struktur und Formatierung
- Regelmäßige Updates

## Troubleshooting

### Häufige Probleme
1. Git-Hooks funktionieren nicht:
   ```powershell
   # Neu installieren
   .\KI-Klaus\scripts\setup\init_git.ps1
   ```

2. Task-Status wird nicht aktualisiert:
   - Commit-Message-Format überprüfen
   - Git-Hooks-Installation verifizieren

3. Skript-Ausführungsfehler:
   ```powershell
   # PowerShell-Ausführungsrichtlinie temporär ändern
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

## Support

Bei Fragen oder Problemen:
1. Dokumentation in `KI-Klaus/` prüfen
2. Issues im Template-Repository erstellen
3. Team-Lead kontaktieren

## Lizenz
[Ihre Lizenz hier]

---

*Dieses Template wird kontinuierlich verbessert. Feedback und Verbesserungsvorschläge sind willkommen.*
