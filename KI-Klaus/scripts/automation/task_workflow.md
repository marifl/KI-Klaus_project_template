# Task-Workflow in KI-Klaus

## Grundprinzipien

1. **Ein Task = Eine Einheit**
   - Eindeutige ID (TASK-[Timestamp])
   - Eigenes Verzeichnis
   - Eigener Git-Branch
   - Vollständige Dokumentation

2. **Klare Statusübergänge**
   ```
   NEW -> IN_PROGRESS -> REVIEW -> TESTING -> COMPLETED
   ```

## Verzeichnisstruktur

```
dev/
└── tasks/
    ├── active/
    │   └── TASK-[ID]/
    │       ├── description.md    # Task-Beschreibung und Status
    │       └── thoughts/         # KI-Klaus Gedanken und Kontext
    └── completed/
        └── [YYYY-MM]/           # Archivierte Tasks nach Monat
```

## Task-Lebenszyklus

### 1. Task-Erstellung
1. Task-ID generieren
2. Verzeichnis erstellen
3. Task-Beschreibung initialisieren
4. Git-Branch von develop erstellen
5. Thoughts-Verzeichnis für KI-Klaus vorbereiten

### 2. Task-Bearbeitung
1. Status-Updates dokumentieren
2. Gedanken und Kontext in thoughts/ speichern
3. Commits mit Task-ID markieren

### 3. Task-Abschluss
1. Status auf COMPLETED setzen
2. In completed/[YYYY-MM]/ archivieren
3. Branch mergen
4. Verzeichnis aufräumen

## Git-Integration

### Branch-Konvention
```
feature/TASK-[ID]-beschreibung
bugfix/TASK-[ID]-beschreibung
refactor/TASK-[ID]-beschreibung
docs/TASK-[ID]-beschreibung
```

### Commit-Message-Format
```
[TASK-ID] Typ: Kurze Beschreibung

- Detaillierte Beschreibung
- Weitere Informationen

Task: #TASK-ID
Status: [IN_PROGRESS|COMPLETED|TESTING]
```

## Skript-Verwendung

### 1. Task-Management-Modul (task_manager.ps1)
- Hauptwerkzeug für Task-Verwaltung
- Bietet alle Task-Operationen
- Konsolenbasierte Interaktion

```powershell
# Task erstellen
New-Task -Description "Neue Funktion" -Type feature

# Status aktualisieren
Update-TaskStatus -TaskId "TASK-123" -Status "IN_PROGRESS"

# Aktive Tasks anzeigen
Get-ActiveTasks
```

### 2. Task-Liste (task_list.ps1)
- Nur für schnelle Übersicht
- JSON-Output für KI-Klaus
- Keine Modifikationen

```powershell
.\task_list.ps1 -Status ALL
```

## Best Practices

1. **Task-Erstellung**
   - Aussagekräftige Beschreibungen
   - Klare Akzeptanzkriterien
   - Logische Branch-Namen

2. **Task-Bearbeitung**
   - Regelmäßige Status-Updates
   - Dokumentierte Gedankengänge
   - Saubere Commit-Messages

3. **Task-Abschluss**
   - Vollständige Dokumentation
   - Sauberes Merging
   - Korrekte Archivierung

## Fehlerbehandlung

1. **Task-Erstellung fehlgeschlagen**
   - Verzeichnisstruktur prüfen
   - Git-Status überprüfen
   - Berechtigungen validieren

2. **Status-Update fehlgeschlagen**
   - Task-Existenz prüfen
   - Gültigen Status verwenden
   - Dateizugriff sicherstellen

3. **Branch-Probleme**
   - Git-Status prüfen
   - Branch-Existenz verifizieren
   - Merge-Konflikte lösen

## Zusammenfassung

Der Task-Workflow ist:
1. Logisch strukturiert
2. Klar dokumentiert
3. Git-integriert
4. Nachvollziehbar
5. Wartbar

Jeder Schritt folgt einer klaren Logik und ist Teil eines größeren, zusammenhängenden Systems.
