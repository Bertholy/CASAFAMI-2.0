<#
.SYNOPSIS
    Lance CASAFAMI en développement : le serveur (port 8080) et le site (port 5173), chacun dans sa fenêtre.
    Fermez les deux fenêtres pour arrêter.
#>
$ErrorActionPreference = 'Stop'
if (-not (Test-Path (Join-Path $PSScriptRoot 'backend\cabinet\config\application.properties'))) {
    Write-Host "Configuration absente : lancez d'abord .\setup.ps1" -ForegroundColor Red; exit 1
}
# Le projet vise Java 17 : Lombok ne sait pas encore compiler sous un JDK trop récent (ex. 27 : « ExceptionInInitializerError: EndPosTable »).
$jdk17 = 'C:\Program Files\Java\jdk-17'
$demarrage = if (Test-Path $jdk17) { "`$env:JAVA_HOME = '$jdk17'; .\mvnw.cmd spring-boot:run" } else { '.\mvnw.cmd spring-boot:run' }
Start-Process powershell -WorkingDirectory (Join-Path $PSScriptRoot 'backend\cabinet') -ArgumentList '-NoExit', '-Command', $demarrage
Start-Process powershell -WorkingDirectory (Join-Path $PSScriptRoot 'frontend') -ArgumentList '-NoExit', '-Command', 'npm run dev'
Write-Host 'Serveur : http://localhost:8080   Site : http://localhost:5173  (patientez 30 a 60 secondes au premier demarrage)' -ForegroundColor Green
