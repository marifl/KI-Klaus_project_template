# Implementierungsplan: Git-Integration in Template

## 1. Verzeichnisstruktur anpassen

### Neue Struktur erstellen
```plaintext
KI-Klaus/
├── roles/                    # Bestehende Rollen-Dokumente
├── templates/               # Neue Template-Struktur
│   ├── git/
│   │   ├── hooks/          # Git Hooks
│   │   ├── .gitmessage     # Commit Message Template
│   │   └── .gitignore      # Standard Gitignore
│   ├── tasks/              # Task Templates
│   └── docs/               # Dokumentation Templates
├── scripts/                # Automatisierungsskripte
│   ├── setup/
│   │   ├── init_git.sh     # Git-Setup
│   │   └── init_hooks.sh   # Hooks-Installation
│   └── automation/
│       ├── task_manager.sh # Task-Management
│       └── doc_generator.sh # Dokumentationsgenerierung
└── config/                 # Konfigurationsdateien
    ├── git/
    └── automation/
```

## 2. Template-Dateien erstellen

### Git-Templates
```bash
# KI-Klaus/templates/git/hooks/post-commit
#!/bin/bash
task_id=$(git rev-parse --abbrev-ref HEAD | grep -oP 'TASK-\d+')
if [ ! -z "$task_id" ]; then
    ../scripts/automation/update_task_status.sh "$task_id"
fi
```

### Task-Templates
```markdown
# KI-Klaus/templates/tasks/task_template.md
---
task_id: TASK-{ID}
status: NEW
branch: {BRANCH_NAME}
created: {TIMESTAMP}
---

## Beschreibung
{DESCRIPTION}

## Akzeptanzkriterien
- [ ] Kriterium 1
- [ ] Kriterium 2

## Git-Integration
- Branch: `{BRANCH_NAME}`
- Status: Wird automatisch aktualisiert
```

## 3. Automatisierungsskripte

### Setup-Skripte
```bash
# KI-Klaus/scripts/setup/init_git.sh
#!/bin/bash

# Git initialisieren
git init

# Templates kopieren
cp -r KI-Klaus/templates/git/.gitmessage .
cp -r KI-Klaus/templates/git/.gitignore .

# Hooks installieren
./init_hooks.sh

# Initiale Branches erstellen
git checkout -b main
git checkout -b develop
```

### Task-Management-Skripte
```bash
# KI-Klaus/scripts/automation/task_manager.sh
#!/bin/bash

function create_task() {
    timestamp=$(date +%Y%m%d_%H%M%S)
    task_id="TASK-$timestamp"
    
    # Task-Verzeichnis erstellen
    mkdir -p "dev/tasks/active/$task_id"
    
    # Task-Template kopieren und anpassen
    envsubst < KI-Klaus/templates/tasks/task_template.md > "dev/tasks/active/$task_id/description.md"
    
    # Git-Branch erstellen
    git checkout -b "feature/$task_id-$1" develop
}
```

## 4. Implementierungsschritte

### Schritt 1: Template-Struktur aktualisieren
```bash
# Neue Verzeichnisse erstellen
mkdir -p KI-Klaus/templates/{git,tasks,docs}
mkdir -p KI-Klaus/scripts/{setup,automation}
mkdir -p KI-Klaus/config/{git,automation}

# Templates verschieben und anpassen
mv KI-Klaus/role_*.md KI-Klaus/roles/
```

### Schritt 2: Git-Setup
```bash
# Git initialisieren und konfigurieren
./KI-Klaus/scripts/setup/init_git.sh

# Commit Message Template aktivieren
git config --local commit.template .gitmessage
```

### Schritt 3: Task-System anpassen
```bash
# Task-Verzeichnisstruktur erstellen
mkdir -p dev/tasks/{active,completed}

# Bestehende Tasks migrieren
./KI-Klaus/scripts/automation/migrate_tasks.sh
```

### Schritt 4: Dokumentation aktualisieren
```bash
# Dokumentation der neuen Struktur
cp git_workflow.md docs/manual/
cp git_integration.md docs/manual/
```

## 5. Konfigurationsdateien

### Git-Konfiguration
```yaml
# KI-Klaus/config/git/config.yml
branches:
  main: protected
  develop: protected
  feature: TASK-*
  bugfix: TASK-*
  
commit_template:
  enabled: true
  path: .gitmessage
```

### Automatisierungs-Konfiguration
```yaml
# KI-Klaus/config/automation/config.yml
task_management:
  template_path: KI-Klaus/templates/tasks
  active_path: dev/tasks/active
  completed_path: dev/tasks/completed
  
documentation:
  auto_generate: true
  templates_path: KI-Klaus/templates/docs
```

## 6. Update der bestehenden Dokumente

### hello.ai anpassen
```markdown
# Ergänzung in hello.ai

## Git-Integration

1. **Projekt-Setup**
   - Repository wird automatisch initialisiert
   - Branching-Strategie wird eingerichtet
   - Hooks werden installiert

2. **Task-Management**
   - Tasks sind mit Git-Branches verknüpft
   - Status-Updates erfolgen automatisch
   - Dokumentation wird automatisch generiert
```

### Rolle "DevOps Engineer" aktualisieren
```markdown
# Ergänzung in role_devops_engineer.md

## Git-Verantwortlichkeiten

- Überwachung der Git-Integration
- Wartung der Automatisierungsskripte
- Sicherstellung der CI/CD-Pipeline
```

## 7. Testplan

### Funktionstest
1. Neuen Task erstellen
2. Branch automatisch erstellen
3. Commits durchführen
4. Status-Updates überprüfen
5. Dokumentation validieren

### Migrationstest
1. Bestehende Tasks migrieren
2. Dokumentation überprüfen
3. Git-Historie validieren

## 8. Rollback-Plan

### Sicherung
```bash
# Vor der Migration
cp -r dev/currentTask_* backup/
cp -r docs/ backup/
```

### Rollback-Skript
```bash
#!/bin/bash
# rollback.sh

# Git-Konfiguration zurücksetzen
git config --local --unset commit.template

# Verzeichnisse wiederherstellen
rm -rf dev/tasks/
mv backup/currentTask_* dev/
mv backup/docs/* docs/
```

Diese Implementierung:
1. Behält die bewährte Struktur des Templates
2. Integriert Git nahtlos in den Workflow
3. Automatisiert Task-Management und Dokumentation
4. Bietet klare Rollback-Möglichkeiten

Die Umsetzung erfolgt schrittweise und kann jederzeit rückgängig gemacht werden.
