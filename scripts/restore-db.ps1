<#
.SYNOPSIS
    Restaure une sauvegarde créée par backup-db.ps1.

.DESCRIPTION
    Par sécurité, la restauration se fait dans une NOUVELLE base (par défaut « casafami_restauree »), jamais par-dessus la base
    en service. Vérifiez son contenu, puis, si tout est bon, arrêtez l'application et faites pointer CASAFAMI_DB_URL vers cette base
    (ou renommez les bases avec pgAdmin).

.EXAMPLE
    .\restore-db.ps1 -Fichier ..\backups\casafami-20261010-180000.dump
    .\restore-db.ps1 -Fichier ..\backups\casafami-20261010-180000.dump -DbName casafami_test_restauration
#>
param(
    [Parameter(Mandatory = $true)][string]$Fichier,
    [string]$DbName = 'casafami_restauree',
    [string]$DbHost = $(if ($env:CASAFAMI_DB_HOST) { $env:CASAFAMI_DB_HOST } else { 'localhost' }),
    [int]$Port = $(if ($env:CASAFAMI_DB_PORT) { [int]$env:CASAFAMI_DB_PORT } else { 5432 }),
    [string]$DbUser = $(if ($env:CASAFAMI_DB_USER) { $env:CASAFAMI_DB_USER } else { 'postgres' })
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Fichier)) { throw "Fichier introuvable : $Fichier" }
if ($DbName -eq 'casafami') { throw "Refusé : ne restaurez jamais directement dans la base en service « casafami ». Choisissez un autre nom." }

$bin = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
function Outil($nom) {
    $chemin = (Get-Command $nom -ErrorAction SilentlyContinue).Source
    if (-not $chemin -and $bin) { $chemin = Join-Path $bin "$nom.exe" }
    if (-not $chemin) { throw "$nom est introuvable. Ajoutez le dossier « bin » de PostgreSQL au PATH." }
    return $chemin
}

if (-not $env:PGPASSWORD) {
    if ($env:CASAFAMI_DB_PASSWORD) { $env:PGPASSWORD = $env:CASAFAMI_DB_PASSWORD }
    else { throw "Mot de passe de la base inconnu : définissez la variable CASAFAMI_DB_PASSWORD (ou PGPASSWORD)." }
}

& (Outil 'createdb') -h $DbHost -p $Port -U $DbUser -E UTF8 $DbName
if ($LASTEXITCODE -ne 0) { throw "Création de la base « $DbName » impossible (existe-t-elle déjà ?)." }
& (Outil 'pg_restore') -h $DbHost -p $Port -U $DbUser -d $DbName --no-owner $Fichier
if ($LASTEXITCODE -ne 0) { throw "pg_restore a échoué (code $LASTEXITCODE)." }
Write-Host "Sauvegarde restaurée dans la base « $DbName ». Vérifiez-la avant de l'utiliser."
