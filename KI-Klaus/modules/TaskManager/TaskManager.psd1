@{
    RootModule = 'TaskManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = '12345678-90ab-cdef-1234-567890abcdef'
    Author = 'KI-Klaus'
    Description = 'Task Management Module for KI-Klaus'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('New-Task', 'Update-TaskStatus', 'Get-ActiveTasks')
    PrivateData = @{
        PSData = @{
            Tags = @('KI-Klaus', 'TaskManagement')
            ProjectUri = 'https://github.com/yourusername/KI-Klaus'
        }
    }
}
