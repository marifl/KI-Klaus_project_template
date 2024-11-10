# Export-DirectoryStructure.ps1
# Dieses Skript exportiert die vollständige Verzeichnisstruktur des aktuellen Verzeichnisses rekursiv in eine .txt-Datei

# Das Verzeichnis, in dem das Skript gespeichert ist, als Ausgangsverzeichnis verwenden
$projectPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Ausgabe-Datei (wo die Verzeichnisstruktur gespeichert wird)
$outputFile = Join-Path -Path $projectPath -ChildPath "directory_structure.txt"

# Leere die Ausgabedatei, falls sie bereits existiert, oder erstelle sie, wenn sie nicht existiert
if (Test-Path $outputFile) {
    Clear-Content -Path $outputFile
} else {
    New-Item -Path $outputFile -ItemType File -Force | Out-Null
}

# Funktion zum Abrufen der Verzeichnisstruktur rekursiv
function Get-DirectoryStructure {
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

        # Wenn es ein Ordner ist
        if ($item.PSIsContainer) {
            # Schreibe den Ordnernamen in die Datei mit entsprechendem Symbol
            Add-Content -Path $outputFile -Value ("$indent" + ($isLastItem ? "└── " : "├── ") + $item.Name)

            # Rekursiver Aufruf für den nächsten Verzeichnisebene
            Get-DirectoryStructure -Path $item.FullName -Level ($Level + 1)
        } else {
            # Wenn es eine Datei ist, schreibe den Dateinamen in die Datei mit entsprechendem Symbol
            Add-Content -Path $outputFile -Value ("$indent" + ($isLastItem ? "└── " : "├── ") + $item.Name)
        }
    }
}

# Start der Verzeichnisstruktur-Erstellung
Add-Content -Path $outputFile -Value ("Projektstruktur von: " + $projectPath)
Add-Content -Path $outputFile -Value ("======================================")
Get-DirectoryStructure -Path $projectPath

Write-Output "Verzeichnisstruktur wurde erfolgreich in $outputFile gespeichert."
