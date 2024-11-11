@{
    RootModule = 'ThoughtManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = '98765432-10fe-dcba-9876-543210fedcba'
    Author = 'KI-Klaus'
    Description = 'Thought Management Module for KI-Klaus'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('New-TaskThoughts', 'Get-LatestTaskThoughts')
    PrivateData = @{
        PSData = @{
            Tags = @('KI-Klaus', 'ThoughtManagement')
            ProjectUri = 'https://github.com/yourusername/KI-Klaus'
        }
    }
}
