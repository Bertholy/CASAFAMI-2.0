<#
.SYNOPSIS
    Sauvegarde de la base PostgreSQL du cabinet (et des photos téléversées).

.DESCRIPTION
    Crée un fichier « casafami-AAAAMMJJ-HHMMSS.dump » (format PostgreSQL compressé) dans le dossier de sauvegarde,
    puis une archive des photos (services et profils), et supprime les sauvegardes les plus anciennes.
    Les paramètres par défaut suivent ceux de l'application (variables CASAFAMI_DB_*).

.EXAMPLE
    .\backup-db.ps1
    .\backup-db.ps1 -Destination D:\sauvegardes -Garder 30

    Pour une sauvegarde chaque nuit : Planificateur de tâches Windows → action « powershell.exe -File C:\...\backup-db.ps1 ».
#>
param(
    [string]$Destination = (Join-Path $PSScriptRoot '..\backups'),
    [string]$DbHost = $(if ($env:CASAFAMI_DB_HOST) { $env:CASAFAMI_DB_HOST } else { 'localhost' }),
    [int]$Port = $(if ($env:CASAFAMI_DB_PORT) { [int]$env:CASAFAMI_DB_PORT } else { 5432 }),
    [string]$DbName = $(if ($env:CASAFAMI_DB_NAME) { $env:CASAFAMI_DB_NAME } else { 'casafami' }),
    [string]$DbUser = $(if ($env:CASAFAMI_DB_USER) { $env:CASAFAMI_DB_USER } else { 'postgres' }),
    [string]$Uploads = (Join-Path $PSScriptRoot '..\backend\cabinet\uploads'),
    [int]$Garder = 14
)

$ErrorActionPreference = 'Stop'

# Retrouve pg_dump : dans le PATH, sinon dans l'installation standard de PostgreSQL.
$pgDump = (Get-Command pg_dump -ErrorAction SilentlyContinue).Source
if (-not $pgDump) {
    $pgDump = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\pg_dump.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $pgDump) { throw "pg_dump est introuvable. Ajoutez le dossier « bin » de PostgreSQL au PATH." }

if (-not $env:PGPASSWORD) {
    if ($env:CASAFAMI_DB_PASSWORD) { $env:PGPASSWORD = $env:CASAFAMI_DB_PASSWORD }
    else { throw "Mot de passe de la base inconnu : définissez la variable CASAFAMI_DB_PASSWORD (ou PGPASSWORD)." }
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$dump = Join-Path $Destination "casafami-$stamp.dump"

& $pgDump -h $DbHost -p $Port -U $DbUser -F c -f $dump $DbName
if ($LASTEXITCODE -ne 0) { Remove-Item $dump -ErrorAction SilentlyContinue; throw "pg_dump a échoué (code $LASTEXITCODE)." }
Write-Host "Base sauvegardée : $dump ($([math]::Round((Get-Item $dump).Length / 1KB)) Ko)"

if (Test-Path $Uploads) {
    $zip = Join-Path $Destination "photos-$stamp.zip"
    Compress-Archive -Path (Join-Path $Uploads '*') -DestinationPath $zip -Force
    Write-Host "Photos sauvegardées : $zip"
}

# Rotation : on ne garde que les N sauvegardes les plus récentes de chaque type.
foreach ($motif in 'casafami-*.dump', 'photos-*.zip') {
    Get-ChildItem $Destination -Filter $motif | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Garder | Remove-Item -Force
}
Write-Host "Terminé. Conservez aussi une copie hors de cet ordinateur (clé USB, disque externe, stockage en ligne)."
