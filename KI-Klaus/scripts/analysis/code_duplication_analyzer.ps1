# Code Duplication Analyzer
# Analysiert Code auf Duplikate und ähnliche Patterns
# Optimiert für Token-Effizienz und modulare Struktur

#Requires -Version 5.1

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$Path = ".",
    
    [Parameter(Mandatory=$false)]
    [string[]]$FileTypes = @("*.ps1", "*.psm1", "*.cs", "*.js", "*.ts", "*.py"),
    
    [Parameter(Mandatory=$false)]
    [int]$MinimumLines = 3,
    
    [Parameter(Mandatory=$false)]
    [int]$SimilarityThreshold = 80,
    
    [Parameter(Mandatory=$false)]
    [switch]$JsonOutput,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeComments,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$DetailedAnalysis
)

# Lade Umgebungsvariablen
$envLoader = Join-Path $PSScriptRoot "..\..\scripts\core\load-env.ps1"
if (Test-Path $envLoader) {
    . $envLoader
    Initialize-KIKlausEnvironment -Verbose
}

# Klasse für Code-Blöcke
class CodeBlock {
    [string]$FilePath
    [int]$StartLine
    [int]$EndLine
    [string]$Content
    [string]$Hash
    [System.Collections.Generic.List[string]]$Tokens
    
    CodeBlock($file, $start, $end, $content) {
        $this.FilePath = $file
        $this.StartLine = $start
        $this.EndLine = $end
        $this.Content = $content
        $this.Hash = Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($content))) -Algorithm MD5 | Select-Object -ExpandProperty Hash
        $this.Tokens = [System.Collections.Generic.List[string]]::new()
    }
}

# Klasse für Duplikat-Gruppen
class DuplicateGroup {
    [System.Collections.Generic.List[CodeBlock]]$Blocks
    [int]$TotalOccurrences
    [int]$TotalLines
    [double]$SimilarityScore
    
    DuplicateGroup() {
        $this.Blocks = [System.Collections.Generic.List[CodeBlock]]::new()
        $this.TotalOccurrences = 0
        $this.TotalLines = 0
        $this.SimilarityScore = 0.0
    }
}

# Funktion zum Tokenisieren von Code
function Get-CodeTokens {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Content
    )
    
    # Entferne Kommentare wenn nicht explizit eingeschlossen
    if (-not $IncludeComments) {
        $Content = $Content -replace '#.*$', '' -replace '//.*$', '' -replace '/\*[\s\S]*?\*/', ''
    }
    
    # Normalisiere Whitespace
    $Content = $Content -replace '\s+', ' '
    
    # Tokenisierung
    $tokens = $Content -split '\W+' | Where-Object { $_ -ne '' }
    
    return $tokens
}

# Funktion zum Extrahieren von Code-Blöcken
function Get-CodeBlocks {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    $blocks = [System.Collections.Generic.List[CodeBlock]]::new()
    $content = Get-Content $FilePath -Raw
    $lines = $content -split "`n"
    
    $currentBlock = @()
    $startLine = 1
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        
        if ($line -ne '') {
            $currentBlock += $line
        }
        
        if (($line -eq '') -or ($i -eq $lines.Count - 1)) {
            if ($currentBlock.Count -ge $MinimumLines) {
                $blockContent = $currentBlock -join "`n"
                $block = [CodeBlock]::new($FilePath, $startLine, $startLine + $currentBlock.Count - 1, $blockContent)
                $block.Tokens.AddRange([string[]]$(Get-CodeTokens -Content $blockContent))
                $blocks.Add($block)
            }
            $currentBlock = @()
            $startLine = $i + 2
        }
    }
    
    return $blocks
}

# Funktion zum Berechnen der Ähnlichkeit
function Get-TokenSimilarity {
    param (
        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.List[string]]$Tokens1,
        
        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.List[string]]$Tokens2
    )
    
    $set1 = [System.Collections.Generic.HashSet[string]]::new($Tokens1)
    $set2 = [System.Collections.Generic.HashSet[string]]::new($Tokens2)
    
    $intersection = [System.Collections.Generic.HashSet[string]]::new($set1)
    $intersection.IntersectWith($set2)
    
    $union = [System.Collections.Generic.HashSet[string]]::new($set1)
    $union.UnionWith($set2)
    
    if ($union.Count -eq 0) { return 0 }
    
    return ($intersection.Count / $union.Count) * 100
}

# Hauptanalyse-Funktion
function Start-DuplicationAnalysis {
    Write-Verbose "Starte Code-Duplikat-Analyse..."
    
    # Sammle alle Dateien
    $files = Get-ChildItem -Path $Path -Recurse -Include $FileTypes
    Write-Verbose "Gefundene Dateien: $($files.Count)"
    
    # Extrahiere Code-Blöcke
    $allBlocks = [System.Collections.Generic.List[CodeBlock]]::new()
    foreach ($file in $files) {
        $blocks = Get-CodeBlocks -FilePath $file.FullName
        $allBlocks.AddRange($blocks)
    }
    Write-Verbose "Extrahierte Code-Blöcke: $($allBlocks.Count)"
    
    # Finde Duplikate
    $duplicateGroups = [System.Collections.Generic.List[DuplicateGroup]]::new()
    $processedHashes = [System.Collections.Generic.HashSet[string]]::new()
    
    foreach ($block in $allBlocks) {
        if ($processedHashes.Contains($block.Hash)) { continue }
        
        $group = [DuplicateGroup]::new()
        $group.Blocks.Add($block)
        
        # Suche ähnliche Blöcke
        foreach ($otherBlock in $allBlocks) {
            if ($block.Hash -eq $otherBlock.Hash -and $block.FilePath -ne $otherBlock.FilePath) {
                $similarity = Get-TokenSimilarity -Tokens1 $block.Tokens -Tokens2 $otherBlock.Tokens
                if ($similarity -ge $SimilarityThreshold) {
                    $group.Blocks.Add($otherBlock)
                    $processedHashes.Add($otherBlock.Hash)
                }
            }
        }
        
        if ($group.Blocks.Count -gt 1) {
            $group.TotalOccurrences = $group.Blocks.Count
            $group.TotalLines = ($group.Blocks | Measure-Object -Property { $_.EndLine - $_.StartLine + 1 } -Sum).Sum
            $group.SimilarityScore = ($group.Blocks | ForEach-Object { Get-TokenSimilarity -Tokens1 $group.Blocks[0].Tokens -Tokens2 $_.Tokens } | Measure-Object -Average).Average
            $duplicateGroups.Add($group)
        }
    }
    
    # Erstelle Ergebnis
    $result = @{
        Summary = @{
            TotalFiles = $files.Count
            TotalBlocks = $allBlocks.Count
            DuplicateGroups = $duplicateGroups.Count
            TotalDuplicates = ($duplicateGroups | Measure-Object -Property TotalOccurrences -Sum).Sum
            TotalDuplicateLines = ($duplicateGroups | Measure-Object -Property TotalLines -Sum).Sum
        }
        Details = $duplicateGroups | ForEach-Object {
            @{
                Occurrences = $_.TotalOccurrences
                Lines = $_.TotalLines
                SimilarityScore = [math]::Round($_.SimilarityScore, 2)
                Locations = $_.Blocks | ForEach-Object {
                    @{
                        File = $_.FilePath
                        StartLine = $_.StartLine
                        EndLine = $_.EndLine
                        Content = if ($DetailedAnalysis) { $_.Content } else { $null }
                    }
                }
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
        Write-Host "`nCode-Duplikat-Analyse Zusammenfassung:" -ForegroundColor Cyan
        Write-Host "--------------------------------" -ForegroundColor Cyan
        Write-Host "Analysierte Dateien: $($result.Summary.TotalFiles)"
        Write-Host "Gefundene Code-Blöcke: $($result.Summary.TotalBlocks)"
        Write-Host "Duplikat-Gruppen: $($result.Summary.DuplicateGroups)"
        Write-Host "Gesamtanzahl Duplikate: $($result.Summary.TotalDuplicates)"
        Write-Host "Duplizierte Zeilen: $($result.Summary.TotalDuplicateLines)"
        
        if ($DetailedAnalysis) {
            Write-Host "`nDetaillierte Duplikat-Informationen:" -ForegroundColor Yellow
            foreach ($group in $result.Details) {
                Write-Host "`nDuplikat-Gruppe:" -ForegroundColor Green
                Write-Host "Vorkommen: $($group.Occurrences)"
                Write-Host "Zeilen: $($group.Lines)"
                Write-Host "Ähnlichkeit: $($group.SimilarityScore)%"
                Write-Host "Fundorte:"
                foreach ($location in $group.Locations) {
                    Write-Host "- $($location.File):$($location.StartLine)-$($location.EndLine)"
                    if ($location.Content) {
                        Write-Host $location.Content
                    }
                }
            }
        }
    }
}

# Führe Analyse aus
Start-DuplicationAnalysis
