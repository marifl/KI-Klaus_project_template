# Git-basiertes Versionierungssystem

## 1. Grundstruktur

### Branches
```
main (oder master)
├── develop
│   ├── feature/*
│   ├── bugfix/*
│   └── refactor/*
├── release/*
└── hotfix/*
```

### Branch-Namenskonventionen
- `feature/TASK-ID-kurze-beschreibung`
- `bugfix/TASK-ID-kurze-beschreibung`
- `refactor/TASK-ID-kurze-beschreibung`
- `release/v1.x.x`
- `hotfix/v1.x.x-kurze-beschreibung`

## 2. Integration mit Task-Management

### Commit-Nachrichten-Format
```
[TASK-ID] Typ: Kurze Beschreibung

- Detaillierte Beschreibung der Änderungen
- Weitere relevante Informationen

Task: #TASK-ID
```

### Commit-Typen
- `feat:` Neue Features
- `fix:` Bugfixes
- `refactor:` Code-Refactoring
- `docs:` Dokumentationsänderungen
- `test:` Test-bezogene Änderungen
- `chore:` Routine-Tasks, Maintenance

## 3. Automatisierung

### Git Hooks
```bash
# pre-commit
#!/bin/bash
# Validierung der Commit-Nachricht
# Automatische Formatierung
# Lint-Checks

# post-commit
#!/bin/bash
# Aktualisierung der Task-Status
# Dokumentations-Updates
```

### GitHub Actions / GitLab CI
```yaml
# Beispiel-Workflow
name: Task Integration
on: [push, pull_request]

jobs:
  update-tasks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Update Task Status
        run: |
          # Task-Status basierend auf Commits aktualisieren
          # Dokumentation automatisch generieren
```

## 4. Workflow-Prozess

### Feature-Entwicklung
1. Task aus dem Backlog auswählen
2. Neuen Feature-Branch erstellen:
   ```bash
   git checkout -b feature/TASK-ID-beschreibung develop
   ```
3. Entwicklung mit regelmäßigen Commits:
   ```bash
   git commit -m "[TASK-ID] feat: Implementiere XYZ
   
   - Detaillierte Beschreibung
   - Weitere Informationen
   
   Task: #TASK-ID"
   ```
4. Pull Request erstellen
5. Code Review
6. Merge in develop

### Release-Prozess
1. Release-Branch erstellen:
   ```bash
   git checkout -b release/v1.x.x develop
   ```
2. Version bump und letzte Tests
3. Merge in main und develop:
   ```bash
   git checkout main
   git merge --no-ff release/v1.x.x
   git tag -a v1.x.x -m "Version 1.x.x"
   git checkout develop
   git merge --no-ff release/v1.x.x
   ```

## 5. Automatische Dokumentation

### Changelog-Generierung
```bash
#!/bin/bash
# Automatische Changelog-Generierung basierend auf Commit-Nachrichten
# Kategorisierung nach Commit-Typen
# Verlinkung zu Tasks
```

### Task-Status-Updates
```javascript
// Beispiel Task-Update-Logik
function updateTaskStatus(commitMessage) {
  const taskId = extractTaskId(commitMessage);
  const status = determineStatus(commitMessage);
  updateTaskInSystem(taskId, status);
}
```

## 6. Migration zum neuen System

### Schritte
1. Git-Repository initialisieren
2. Branches einrichten
3. Hooks installieren
4. CI/CD-Pipeline konfigurieren
5. Team schulen

### Migrations-Skript
```bash
#!/bin/bash
# Repository initialisieren
git init

# Branches erstellen
git checkout -b develop
git checkout -b feature/initial-setup

# Hooks installieren
cp hooks/* .git/hooks/
chmod +x .git/hooks/*

# Erste Commits
git add .
git commit -m "[TASK-0] chore: Initiales Projekt-Setup

- Git-Workflow eingerichtet
- Hooks installiert
- Grundstruktur erstellt

Task: #TASK-0"
```

## 7. Best Practices

### Code Review
- Pull Request Template verwenden
- Automatische Checks vor Merge
- Code Coverage überprüfen
- Dokumentation validieren

### Branch Protection
```json
{
  "protect": "main",
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "continuous-integration/travis-ci",
      "code-review/approved"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  }
}
```

## 8. Tooling und Integration

### Empfohlene Tools
- Git Flow für Branch-Management
- Husky für Git Hooks
- Commitlint für Commit-Message-Validierung
- Semantic Release für automatische Versionierung

### Konfigurationsbeispiele
```json
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'task-id': [2, 'always'],
    'body-max-line-length': [2, 'always', 100]
  }
};

// .huskyrc
{
  "hooks": {
    "commit-msg": "commitlint -E HUSKY_GIT_PARAMS",
    "pre-commit": "lint-staged"
  }
}
```

Diese Struktur ersetzt das bisherige Versionierungssystem und integriert sich nahtlos in den bestehenden Entwicklungsprozess, während sie moderne Git-Workflows und Automatisierung nutzt.
