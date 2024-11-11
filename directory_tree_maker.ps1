﻿# Export-DirectoryStructure.ps1
# Dieses Skript exportiert die vollständige Verzeichnisstruktur des aktuellen Verzeichnisses rekursiv in eine .txt-Datei

# Das Verzeichnis, in dem das Skript gespeichert ist, als Ausgangsverzeichnis verwenden
$projectPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Ausgabe-Datei
$outputFile = Join-Path -Path $projectPath -ChildPath "directory_structure.txt"

# Leere die Ausgabedatei, falls sie bereits existiert, oder erstelle sie, wenn sie nicht existiert
if (Test-Path $outputFile) {
    Clear-Content -Path $outputFile
} else {
    New-Item -Path $outputFile -ItemType File -Force | Out-Null
}

# Funktion zum Abrufen der Verzeichnisstruktur rekursiv (Baum-Ansicht)
function Get-DirectoryTree {
    param (
        [string]$Path,
        [int]$Level = 0
    )

    # Hole alle Dateien und Ordner im aktuellen Verzeichnis
    $items = Get-ChildItem -Path $Path

    foreach ($item in $items) {
        # Einrückung basierend auf dem Verzeichnisebenen-Level
        $indent = " " * ($Level * 4)

        # Bestimme, ob es sich um das letzte Element handelt
        $isLastItem = $item -eq $items[-1]
        $prefix = if ($isLastItem) { "└── " } else { "├── " }

        # Wenn es ein Ordner ist
        if ($item.PSIsContainer) {
            # Schreibe den Ordnernamen in die Datei mit entsprechendem Symbol
            Add-Content -Path $outputFile -Value ($indent + $prefix + $item.Name + "/")

            # Rekursiver Aufruf für den nächsten Verzeichnisebene
            Get-DirectoryTree -Path $item.FullName -Level ($Level + 1)
        } else {
            # Wenn es eine Datei ist, schreibe den Dateinamen in die Datei mit entsprechendem Symbol
            Add-Content -Path $outputFile -Value ($indent + $prefix + $item.Name)
        }
    }
}

# Funktion zum Abrufen der vollständigen Pfade
function Get-DirectoryPaths {
    param (
        [string]$Path
    )

    Add-Content -Path $outputFile -Value "`nRELATIVE PFADE:"
    Add-Content -Path $outputFile -Value "================"
    # Relative Pfade
    Get-ChildItem -Path $Path -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($projectPath.Length + 1)
        if ($_.PSIsContainer) {
            Add-Content -Path $outputFile -Value ($relativePath + "/")
        } else {
            Add-Content -Path $outputFile -Value $relativePath
        }
    }

    Add-Content -Path $outputFile -Value "`nABSOLUTE PFADE:"
    Add-Content -Path $outputFile -Value "==============="
    # Absolute Pfade
    Get-ChildItem -Path $Path -Recurse | ForEach-Object {
        if ($_.PSIsContainer) {
            Add-Content -Path $outputFile -Value ($_.FullName + "/")
        } else {
            Add-Content -Path $outputFile -Value $_.FullName
        }
    }
}

# Start der Verzeichnisstruktur-Erstellung
Add-Content -Path $outputFile -Value ("VERZEICHNISSTRUKTUR")
Add-Content -Path $outputFile -Value ("===================")
Add-Content -Path $outputFile -Value ("Projektpfad: " + $projectPath)
Add-Content -Path $outputFile -Value ("")
Get-DirectoryTree -Path $projectPath
Get-DirectoryPaths -Path $projectPath

Write-Output "Verzeichnisstruktur wurde erfolgreich in $outputFile gespeichert."
