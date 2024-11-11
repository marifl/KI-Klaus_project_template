# Documentation Validator
# Validiert Dokumentationsqualität und Vollständigkeit
# Optimiert für Token-Effizienz und Dokumentations-Standards

#Requires -Version 5.1

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$Path = ".",
    
    [Parameter(Mandatory=$false)]
    [string[]]$FileTypes = @("*.md", "*.txt"),
    
    [Parameter(Mandatory=$false)]
    [switch]$JsonOutput,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$FixIssues,
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckLinks,
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateFormat
)

# Lade Umgebungsvariablen
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

# Dokumentations-Standards
$DOC_STANDARDS = @{
    RequiredSections = @(
        'Beschreibung',
        'Installation',
        'Verwendung',
        'Parameter',
        'Beispiele'
    )
    MinWordCount = 50
    MaxLineLength = 120
    RequiredFiles = @(
        'README.md',
        'CHANGELOG.md',
        'CONTRIBUTING.md'
    )
}

# Klasse für Dokumentations-Issue
class DocIssue {
    [string]$File
    [string]$Type
    [string]$Message
    [int]$Line
    [string]$Severity
    [bool]$CanAutoFix
    
    DocIssue($file, $type, $msg, $line, $severity, $canFix) {
        $this.File = $file
        $this.Type = $type
        $this.Message = $msg
        $this.Line = $line
        $this.Severity = $severity
        $this.CanAutoFix = $canFix
    }
}

# Funktion zum Prüfen von Links
function Test-DocumentationLinks {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Content,
        
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    $issues = [System.Collections.Generic.List[DocIssue]]::new()
    $linkPattern = '\[([^\]]+)\]\(([^\)]+)\)'
    
    $matches = [regex]::Matches($Content, $linkPattern)
    foreach ($match in $matches) {
        $linkText = $match.Groups[1].Value
        $linkUrl = $match.Groups[2].Value
        
        # Prüfe relative Links
        if (-not $linkUrl.StartsWith('http')) {
            $fullPath = Join-Path (Split-Path $FilePath) $linkUrl
            if (-not (Test-Path $fullPath)) {
                $lineNumber = ($Content.Substring(0, $match.Index) -split "`n").Count
                $issues.Add([DocIssue]::new(
                    $FilePath,
                    "BrokenLink",
                    "Defekter relativer Link: $linkUrl",
                    $lineNumber,
                    "Error",
                    $false
                ))
            }
        }
    }
    
    return $issues
}

# Funktion zum Prüfen des Markdown-Formats
function Test-MarkdownFormat {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Content,
        
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    $issues = [System.Collections.Generic.List[DocIssue]]::new()
    $lines = $Content -split "`n"
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Prüfe Zeilenlänge
        if ($line.Length -gt $DOC_STANDARDS.MaxLineLength) {
            $issues.Add([DocIssue]::new(
                $FilePath,
                "LineLength",
                "Zeile überschreitet maximale Länge von $($DOC_STANDARDS.MaxLineLength) Zeichen",
                $i + 1,
                "Warning",
                $true
            ))
        }
        
        # Prüfe Überschriften-Format
        if ($line -match '^#+\s*\w') {
            if (-not ($line -match '^#+\s\w')) {
                $issues.Add([DocIssue]::new(
                    $FilePath,
                    "HeaderFormat",
                    "Überschrift hat kein Leerzeichen nach #",
                    $i + 1,
                    "Warning",
                    $true
                ))
            }
        }
    }
    
    return $issues
}

# Funktion zum Prüfen der Dokumentations-Struktur
function Test-DocumentationStructure {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Content,
        
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    $issues = [System.Collections.Generic.List[DocIssue]]::new()
    
    # Prüfe erforderliche Abschnitte
    foreach ($section in $DOC_STANDARDS.RequiredSections) {
        if (-not ($Content -match "^#+\s*$section")) {
            $issues.Add([DocIssue]::new(
                $FilePath,
                "MissingSection",
                "Erforderlicher Abschnitt fehlt: $section",
                0,
                "Error",
                $false
            ))
        }
    }
    
    # Prüfe Mindest-Wortanzahl
    $wordCount = ($Content -split '\s+').Count
    if ($wordCount -lt $DOC_STANDARDS.MinWordCount) {
        $issues.Add([DocIssue]::new(
            $FilePath,
            "WordCount",
            "Dokumentation hat zu wenig Wörter (Minimum: $($DOC_STANDARDS.MinWordCount))",
            0,
            "Warning",
            $false
        ))
    }
    
    return $issues
}

# Funktion zum Automatischen Fixen von Problemen
function Repair-DocumentationIssues {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.List[DocIssue]]$Issues
    )
    
    $content = Get-Content $FilePath -Raw
    $lines = $content -split "`n"
    $modified = $false
    
    foreach ($issue in $Issues | Where-Object { $_.CanAutoFix }) {
        switch ($issue.Type) {
            "LineLength" {
                if ($issue.Line -gt 0 -and $issue.Line -le $lines.Count) {
                    $line = $lines[$issue.Line - 1]
                    # Teile lange Zeilen
                    if ($line.Length -gt $DOC_STANDARDS.MaxLineLength) {
                        $newLine = ""
                        $words = $line -split '\s+'
                        $currentLength = 0
                        
                        foreach ($word in $words) {
                            if ($currentLength + $word.Length + 1 -gt $DOC_STANDARDS.MaxLineLength) {
                                $newLine += "`n"
                                $currentLength = 0
                            }
                            $newLine += "$word "
                            $currentLength += $word.Length + 1
                        }
                        
                        $lines[$issue.Line - 1] = $newLine.TrimEnd()
                        $modified = $true
                    }
                }
            }
            
            "HeaderFormat" {
                if ($issue.Line -gt 0 -and $issue.Line -le $lines.Count) {
                    $line = $lines[$issue.Line - 1]
                    if ($line -match '^(#+)(\w)') {
                        $lines[$issue.Line - 1] = $line -replace '^(#+)(\w)', '$1 $2'
                        $modified = $true
                    }
                }
            }
        }
    }
    
    if ($modified) {
        $newContent = $lines -join "`n"
        Set-Content -Path $FilePath -Value $newContent -Encoding UTF8
        Write-Verbose "Datei wurde automatisch repariert: $FilePath"
    }
}

# Hauptfunktion zur Dokumentationsvalidierung
function Start-DocumentationValidation {
    Write-Verbose "Starte Dokumentationsvalidierung..."
    
    $allIssues = [System.Collections.Generic.List[DocIssue]]::new()
    
    # Prüfe erforderliche Dateien
    foreach ($reqFile in $DOC_STANDARDS.RequiredFiles) {
        $filePath = Join-Path $Path $reqFile
        if (-not (Test-Path $filePath)) {
            $allIssues.Add([DocIssue]::new(
                $reqFile,
                "MissingFile",
                "Erforderliche Datei fehlt",
                0,
                "Error",
                $false
            ))
        }
    }
    
    # Prüfe alle Dokumentationsdateien
    $files = Get-ChildItem -Path $Path -Recurse -Include $FileTypes
    foreach ($file in $files) {
        Write-Verbose "Prüfe Datei: $($file.FullName)"
        
        $content = Get-Content $file.FullName -Raw
        
        # Struktur-Prüfung
        $structureIssues = Test-DocumentationStructure -Content $content -FilePath $file.FullName
        $allIssues.AddRange($structureIssues)
        
        # Format-Prüfung
        if ($ValidateFormat) {
            $formatIssues = Test-MarkdownFormat -Content $content -FilePath $file.FullName
            $allIssues.AddRange($formatIssues)
        }
        
        # Link-Prüfung
        if ($CheckLinks) {
            $linkIssues = Test-DocumentationLinks -Content $content -FilePath $file.FullName
            $allIssues.AddRange($linkIssues)
        }
    }
    
    # Automatische Reparatur wenn gewünscht
    if ($FixIssues) {
        $fileGroups = $allIssues | Where-Object { $_.CanAutoFix } | Group-Object -Property File
        foreach ($group in $fileGroups) {
            Repair-DocumentationIssues -FilePath $group.Name -Issues $group.Group
        }
    }
    
    # Erstelle Ergebnis
    $result = @{
        Summary = @{
            TotalFiles = $files.Count
            TotalIssues = $allIssues.Count
            ErrorCount = ($allIssues | Where-Object { $_.Severity -eq 'Error' }).Count
            WarningCount = ($allIssues | Where-Object { $_.Severity -eq 'Warning' }).Count
            FixableCount = ($allIssues | Where-Object { $_.CanAutoFix }).Count
        }
        Issues = $allIssues | ForEach-Object {
            @{
                File = $_.File
                Type = $_.Type
                Message = $_.Message
                Line = $_.Line
                Severity = $_.Severity
                CanAutoFix = $_.CanAutoFix
            }
        }
    }
    
    # Ausgabe
    if ($JsonOutput) {
        $output = $result | ConvertTo-Json -Depth 10
        if ($OutputPath) {
            $output | Set-Content -Path $OutputPath -Encoding UTF8
        } else {
            return $output
        }
    } else {
        Write-Host "`nDokumentations-Validierung Zusammenfassung:" -ForegroundColor Cyan
        Write-Host "--------------------------------" -ForegroundColor Cyan
        Write-Host "Geprüfte Dateien: $($result.Summary.TotalFiles)"
        Write-Host "Gefundene Probleme: $($result.Summary.TotalIssues)"
        Write-Host "  - Fehler: $($result.Summary.ErrorCount)"
        Write-Host "  - Warnungen: $($result.Summary.WarningCount)"
        Write-Host "  - Automatisch behebbar: $($result.Summary.FixableCount)"
        
        if ($result.Issues.Count -gt 0) {
            Write-Host "`nGefundene Probleme:" -ForegroundColor Yellow
            foreach ($issue in $result.Issues) {
                $color = if ($issue.Severity -eq 'Error') { 'Red' } else { 'Yellow' }
                Write-Host "`n[$($issue.Severity)] $($issue.File):$($issue.Line)" -ForegroundColor $color
                Write-Host "  $($issue.Type): $($issue.Message)"
                if ($issue.CanAutoFix) {
                    Write-Host "  (Automatisch behebbar)" -ForegroundColor Green
                }
            }
        }
    }
}

# Führe Validierung aus
Start-DocumentationValidation
