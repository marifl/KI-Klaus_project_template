# Enhanced Installation Script für KI-Klaus Module
# Verbesserte Windows 11 Kompatibilität und Fehlerbehandlung

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [string]$CustomPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoBackup
)

# Globale Variablen
$script:logPath = Join-Path $env:TEMP "KIKlaus_Install.log"
$script:backupPath = Join-Path $env:TEMP "KIKlaus_Backup"
$script:minimumPSVersion = "5.1"
$script:recommendedPSVersion = "7.0"

# Logging Funktion
function Write-KIKlausLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    
    # Console Output mit Farben
    switch ($Level) {
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }
    
    # In Log-Datei schreiben
    $logMessage | Out-File $script:logPath -Append
}

# System-Validierung
function Test-SystemRequirements {
    [CmdletBinding()]
    param()
    
    Write-KIKlausLog "Prüfe Systemanforderungen..." -Level Info
    
    $requirements = @{
        IsWindows11 = $false
        PSVersionOK = $false
        HasAdminRights = $false
        ExecutionPolicyOK = $false
        HasEnoughSpace = $false
    }
    
    # Windows 11 Check
    $osVersion = [Environment]::OSVersion.Version
    $requirements.IsWindows11 = ($osVersion.Major -eq 10 -and $osVersion.Build -ge 22000)
    Write-KIKlausLog "Windows Version: $($osVersion.ToString()) $(if($requirements.IsWindows11){'(Windows 11)'}else{'(Nicht Windows 11)'})" -Level $(if($requirements.IsWindows11){'Success'}else{'Warning'})
    
    # PowerShell Version
    $currentVersion = $PSVersionTable.PSVersion
    $requirements.PSVersionOK = $currentVersion -ge [Version]$script:minimumPSVersion
    Write-KIKlausLog "PowerShell Version: $currentVersion (Minimum: $script:minimumPSVersion)" -Level $(if($requirements.PSVersionOK){'Success'}else{'Error'})
    
    # Admin Rechte
    $requirements.HasAdminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-KIKlausLog "Admin Rechte: $(if($requirements.HasAdminRights){'Ja'}else{'Nein'})" -Level $(if($requirements.HasAdminRights){'Success'}else{'Error'})
    
    # Execution Policy
    $policy = Get-ExecutionPolicy
    $requirements.ExecutionPolicyOK = $policy -notin @('Restricted', 'AllSigned')
    Write-KIKlausLog "Execution Policy: $policy" -Level $(if($requirements.ExecutionPolicyOK){'Success'}else{'Warning'})
    
    # Speicherplatz
    $drive = (Get-Item $env:SystemDrive)
    $freeSpace = (Get-PSDrive $drive.Name).Free
    $requirements.HasEnoughSpace = $freeSpace -gt 100MB
    Write-KIKlausLog "Freier Speicherplatz: $([math]::Round($freeSpace / 1MB, 2)) MB" -Level $(if($requirements.HasEnoughSpace){'Success'}else{'Warning'})
    
    return $requirements
}

# Backup Funktion
function Backup-ExistingInstallation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath
    )
    
    if (-not (Test-Path $SourcePath)) {
        Write-KIKlausLog "Keine existierende Installation zum Backup gefunden" -Level Info
        return
    }
    
    $backupDir = Join-Path $script:backupPath (Get-Date -Format "yyyyMMdd_HHmmss")
    Write-KIKlausLog "Erstelle Backup in: $backupDir" -Level Info
    
    try {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Copy-Item -Path "$SourcePath\*" -Destination $backupDir -Recurse -Force
        Write-KIKlausLog "Backup erfolgreich erstellt" -Level Success
    }
    catch {
        Write-KIKlausLog "Fehler beim Backup: $_" -Level Error
        throw
    }
}

# Hauptinstallationsfunktion
function Install-KIKlausModules {
    [CmdletBinding()]
    param()
    
    Write-KIKlausLog "Starte KI-Klaus Module Installation..." -Level Info
    
    try {
        # System-Check
        $sysReq = Test-SystemRequirements
        
        # Kritische Anforderungen prüfen
        if (-not $sysReq.PSVersionOK) {
            throw "PowerShell Version $script:minimumPSVersion oder höher erforderlich"
        }
        
        if (-not $sysReq.HasAdminRights) {
            throw "Administratorrechte erforderlich"
        }
        
        # Warnungen ausgeben
        if (-not $sysReq.IsWindows11) {
            Write-KIKlausLog "Installation auf Nicht-Windows 11 System - Einige Features könnten eingeschränkt sein" -Level Warning
        }
        
        if (-not $sysReq.ExecutionPolicyOK) {
            Write-KIKlausLog "Versuche Execution Policy anzupassen..." -Level Warning
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-KIKlausLog "Execution Policy angepasst" -Level Success
        }
        
        # Installationspfad bestimmen
        $modulePath = if ($CustomPath) {
            $CustomPath
        } elseif ($PSVersionTable.PSEdition -eq 'Core') {
            Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules\KI-Klaus"
        } else {
            Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules\KI-Klaus"
        }
        
        Write-KIKlausLog "Installationspfad: $modulePath" -Level Info
        
        # Backup wenn erforderlich
        if (-not $NoBackup -and (Test-Path $modulePath)) {
            Backup-ExistingInstallation -SourcePath $modulePath
        }
        
        # Installation durchführen
        Write-KIKlausLog "Erstelle Verzeichnisstruktur..." -Level Info
        New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
        
        # Kopiere Module und Dateien
        $sourcePath = Split-Path -Parent $PSScriptRoot
        
        Write-KIKlausLog "Kopiere Module und Konfigurationsdateien..." -Level Info
        
        # TaskManager
        Copy-Item -Path "$sourcePath\modules\TaskManager\*" -Destination "$modulePath\TaskManager" -Recurse -Force
        
        # ThoughtManager
        Copy-Item -Path "$sourcePath\modules\ThoughtManager\*" -Destination "$modulePath\ThoughtManager" -Recurse -Force
        
        # Konfigurationsdateien
        Copy-Item -Path "$sourcePath\scripts\core\registry.json" -Destination "$modulePath\config" -Force
        
        # Templates
        Copy-Item -Path "$sourcePath\templates\tasks\*" -Destination "$modulePath\templates" -Recurse -Force
        
        # Abschlussvalidierung
        Write-KIKlausLog "Validiere Installation..." -Level Info
        $validation = Test-KIKlausInstallation
        
        if ($validation.Success) {
            Write-KIKlausLog "Installation erfolgreich abgeschlossen" -Level Success
            Write-KIKlausLog @"
Installation Details:
- Installationspfad: $modulePath
- PowerShell Version: $($PSVersionTable.PSVersion)
- Execution Policy: $(Get-ExecutionPolicy)
- Log-Datei: $script:logPath
"@ -Level Info
        } else {
            throw "Installation konnte nicht validiert werden"
        }
    }
    catch {
        Write-KIKlausLog "Kritischer Installationsfehler: $_" -Level Error
        Write-KIKlausLog "Installation wird zurückgerollt..." -Level Warning
        
        if (Test-Path $modulePath) {
            Remove-Item -Path $modulePath -Recurse -Force
        }
        
        throw
    }
}

# Validierungsfunktion
function Test-KIKlausInstallation {
    [CmdletBinding()]
    param()
    
    $results = @{
        Success = $true
        Details = @{
            TaskManager = $false
            ThoughtManager = $false
            Config = $false
            Templates = $false
        }
    }
    
    try {
        # TaskManager prüfen
        $results.Details.TaskManager = Test-Path "$modulePath\TaskManager\TaskManager.psm1"
        
        # ThoughtManager prüfen
        $results.Details.ThoughtManager = Test-Path "$modulePath\ThoughtManager\ThoughtManager.psm1"
        
        # Konfiguration prüfen
        $results.Details.Config = Test-Path "$modulePath\config\registry.json"
        
        # Templates prüfen
        $results.Details.Templates = Test-Path "$modulePath\templates\task_template.md"
        
        # Gesamtergebnis
        $results.Success = $results.Details.Values | Where-Object { -not $_ } | Measure-Object | Select-Object -ExpandProperty Count -eq 0
    }
    catch {
        $results.Success = $false
        Write-KIKlausLog "Fehler bei Installationsvalidierung: $_" -Level Error
    }
    
    return $results
}

# Hauptausführung
try {
    Install-KIKlausModules
}
catch {
    Write-KIKlausLog "Installation fehlgeschlagen: $_" -Level Error
    Write-KIKlausLog "Siehe Log-Datei für Details: $script:logPath" -Level Info
    exit 1
}
