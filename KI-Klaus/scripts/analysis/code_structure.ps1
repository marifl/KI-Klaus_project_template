# Code-Struktur-Analyse-Skript
param (
    [Parameter(Mandatory=$false)]
    [string]$Path = "src",
    
    [Parameter(Mandatory=$false)]
    [int]$MaxFileSize = 300
)

function Get-FileStructure {
    param (
        [string]$FilePath
    )
    
    $extension = [System.IO.Path]::GetExtension($FilePath)
    $content = Get-Content $FilePath
    $lineCount = $content.Count
    
    # Funktionen/Klassen basierend auf Dateityp suchen
    $definitions = switch ($extension) {
        ".py" {
            $content | Select-String -Pattern '^\s*(class|def)\s+(\w+)' | 
            ForEach-Object { $_.Matches[0].Groups[1].Value + " " + $_.Matches[0].Groups[2].Value }
        }
        ".js" {
            $content | Select-String -Pattern '^\s*(class|function)\s+(\w+)|^\s*const\s+(\w+)\s*=\s*\([^)]*\)\s*=>' |
            ForEach-Object { 
                if ($_.Matches[0].Groups[1].Value) {
                    $_.Matches[0].Groups[1].Value + " " + $_.Matches[0].Groups[2].Value
                } else {
                    "function " + $_.Matches[0].Groups[3].Value
                }
            }
        }
        ".ts" {
            $content | Select-String -Pattern '^\s*(class|function|interface)\s+(\w+)|^\s*const\s+(\w+)\s*=\s*\([^)]*\)\s*=>' |
            ForEach-Object { 
                if ($_.Matches[0].Groups[1].Value) {
                    $_.Matches[0].Groups[1].Value + " " + $_.Matches[0].Groups[2].Value
                } else {
                    "function " + $_.Matches[0].Groups[3].Value
                }
            }
        }
        default { @() }
    }
    
    # TODOs finden
    $todos = $content | Select-String -Pattern '(?i)TODO:' | ForEach-Object { $_.Line.Trim() }
    
    # Große Dateien markieren
    $isLarge = $lineCount -gt $MaxFileSize
    
    return @{
        Path = $FilePath
        Extension = $extension
        LineCount = $lineCount
        Definitions = $definitions
        Todos = $todos
        IsLarge = $isLarge
    }
}

# Alle relevanten Dateien finden
$files = Get-ChildItem -Path $Path -Recurse -File | 
    Where-Object { $_.Extension -match '\.(py|js|ts|jsx|tsx|cs|java)$' }

# Struktur für jeden File analysieren
$structure = $files | ForEach-Object {
    Get-FileStructure -FilePath $_.FullName
}

# Statistiken erstellen
$statistics = @{
    TotalFiles = $structure.Count
    TotalLines = ($structure | Measure-Object -Property LineCount -Sum).Sum
    LargeFiles = ($structure | Where-Object { $_.IsLarge }).Count
    FilesByType = $structure | Group-Object Extension | Select-Object Name, Count
    TotalDefinitions = ($structure | ForEach-Object { $_.Definitions.Count } | Measure-Object -Sum).Sum
    TotalTodos = ($structure | ForEach-Object { $_.Todos.Count } | Measure-Object -Sum).Sum
}

# Ergebnis zusammenstellen
$result = @{
    Statistics = $statistics
    LargeFiles = $structure | Where-Object { $_.IsLarge } | Select-Object Path, LineCount
    Todos = $structure | Where-Object { $_.Todos.Count -gt 0 } | 
        Select-Object Path, Todos
    Structure = $structure | Select-Object Path, Extension, LineCount, Definitions
}

# Ausgabe als JSON für KI-Klaus
$result | ConvertTo-Json -Depth 10
