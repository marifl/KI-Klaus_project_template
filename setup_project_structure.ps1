# setup_project_structure.ps1

# Parameters
Param(
    [string]$ProjectName = "my_project"
)

# Set the root directory
$rootDir = "./$ProjectName"

# Create directories
$dirs = @(
    "$rootDir/backend/microservice1/src",
    "$rootDir/backend/microservice1/tests",
    "$rootDir/backend/microservice2/src",
    "$rootDir/backend/microservice2/tests",
    "$rootDir/frontend/src",
    "$rootDir/frontend/public",
    "$rootDir/config/dev",
    "$rootDir/config/staging",
    "$rootDir/config/prod",
    "$rootDir/scripts/deployment_scripts",
    "$rootDir/docs",
    "$rootDir/dev",
    "$rootDir/tests/integration_tests",
    "$rootDir/tests/end_to_end_tests"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

# Create placeholder files
$files = @(
    "$rootDir/hello.ai",
    "$rootDir/backend/microservice1/Dockerfile",
    "$rootDir/backend/microservice1/environment.yml",
    "$rootDir/backend/microservice2/Dockerfile",
    "$rootDir/backend/microservice2/environment.yml",
    "$rootDir/frontend/package.json",
    "$rootDir/.env.example",
    "$rootDir/docker-compose.yml",
    "$rootDir/README.md"
)

foreach ($file in $files) {
    New-Item -ItemType File -Force -Path $file | Out-Null
}

# Create templates in docs directory
$templates = @(
    "$rootDir/docs/custom_instructions.md",
    "$rootDir/docs/changelog_TEMPLATE.md",
    "$rootDir/docs/coding_standards.md",
    "$rootDir/docs/directory_map.md",
    "$rootDir/docs/workflow.md",
    "$rootDir/docs/project_map.md"
)

foreach ($template in $templates) {
    New-Item -ItemType File -Force -Path $template | Out-Null
    # Add template header
    Add-Content -Path $template -Value "<!-- TEMPLATE FILE: Do not overwrite or delete -->`n"
}

# Create work-in-progress files in dev directory
$devFiles = @(
    "$rootDir/dev/currentTask.md",
    "$rootDir/dev/notes.md"
)

foreach ($devFile in $devFiles) {
    New-Item -ItemType File -Force -Path $devFile | Out-Null
}

# Write initial content to hello.ai
$helloContent = @"
# Welcome, AI Assistant!

This 'hello.ai' file is your entry point to the project. Please read and follow the instructions carefully.

## Important Instructions

- **Start with 'dev/currentTask.md'**:
  - Always begin by updating and reviewing the current tasks.
  - Use the following format for tasks:
    ```
    [ ] Description of an unfinished task
    [x] Description of a completed task
    ```

- **Follow Custom Instructions**:
  - Refer to 'docs/custom_instructions.md' for core guidelines.
  - Ensure compliance with coding standards and workflows.

- **Maintain the Changelog**:
  - For every change, update the changelog according to 'docs/changelog_TEMPLATE.md'.
  - Create individual changelog files for each version.

- **Update the Project Map**:
  - After any significant change, update 'docs/project_map.md'.
  - This helps maintain context and prevents forgetting important details.

## Reminders

- **Be Concise**: Keep your outputs precise to minimize costs.
- **File Length**: Split files if they exceed 500 lines.
- **Regular Updates**: Continuously update documentation and maps.

Thank you for your assistance!
"@

Set-Content -Path "$rootDir/hello.ai" -Value $helloContent

Write-Host "Project structure for '$ProjectName' has been set up successfully."
