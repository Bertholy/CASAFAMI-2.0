<#
.SYNOPSIS
    Installe tout ce qu'il faut pour lancer CASAFAMI après un « git clone » (Windows).

.DESCRIPTION
    1. vérifie Java 17+, Node 20+ et PostgreSQL ;
    2. récupère le backend et le frontend (sous-modules Git) ;
    3. crée backend\cabinet\config\application.properties (mot de passe PostgreSQL, clé de connexion générée) ;
    4. crée la base de données PostgreSQL ;
    5. installe les dépendances du site (npm ci) et compile le serveur (Maven, télécharge ses bibliothèques).
    Ensuite : .\dev.ps1 lance le serveur et le site.

.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -DbName casafami -DbPassword "mon-mot-de-passe" -AdminEmail admin@casafami.mg -AdminPassword "un-mot-de-passe-long"
#>
param(
    [string]$DbHost = 'localhost',
    [int]$DbPort = 5432,
    [string]$DbName = 'casafami',
    [string]$DbUser = 'postgres',
    [string]$DbPassword = $env:CASAFAMI_DB_PASSWORD,
    [string]$AdminEmail = '',
    [string]$AdminPassword = '',
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Etape($n, $texte) { Write-Host "`n[$n/5] $texte" -ForegroundColor Cyan }
function Manque($texte) { Write-Host "  MANQUE : $texte" -ForegroundColor Red; $script:erreurs += $texte }
$script:erreurs = @()

# ---------------------------------------------------------------- 1. outils
Etape 1 'Verification des outils'
$javaVersion = $null
try { $sortie = (& cmd /c 'java -version 2>&1') -join ' '; if ($sortie -match '"(\d+)') { $javaVersion = [int]$Matches[1] } } catch { }
if ($javaVersion -ge 17) { Write-Host "  Java $javaVersion : ok" } else { Manque 'Java 17 ou plus (JDK) : https://adoptium.net' }
$nodeVersion = $null
try { $v = (& node --version) -replace '^v', ''; $nodeVersion = [int]($v.Split('.')[0]) } catch { }
if ($nodeVersion -ge 20) { Write-Host "  Node $nodeVersion : ok" } else { Manque 'Node.js 20 ou plus : https://nodejs.org' }
$psql = Get-Command psql -ErrorAction SilentlyContinue
if ($psql) { Write-Host '  PostgreSQL (psql) : ok' } else { Write-Host '  psql introuvable : creez la base a la main (CREATE DATABASE casafami ENCODING ''UTF8'';)' -ForegroundColor Yellow }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Manque 'Git : https://git-scm.com' }
if ($script:erreurs.Count -gt 0) { Write-Host "`nInstallez ce qui manque puis relancez .\setup.ps1" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 2. code
Etape 2 'Recuperation du backend et du frontend'
if (Test-Path .git) { git submodule update --init --recursive; if ($LASTEXITCODE -ne 0) { throw 'git submodule a echoue (connexion internet ?)' } }
foreach ($dossier in 'backend\cabinet\pom.xml', 'frontend\package.json') {
    if (-not (Test-Path $dossier)) { throw "Fichier introuvable : $dossier. Clonez avec : git clone --recurse-submodules <adresse>" }
}
Write-Host '  backend et frontend presents'

# ---------------------------------------------------------------- 3. configuration
Etape 3 'Configuration privee (jamais publiee sur GitHub)'
$config = 'backend\cabinet\config\application.properties'
if (Test-Path $config) {
    Write-Host "  $config existe deja : conserve"
} else {
    if (-not $DbPassword) {
        $saisie = Read-Host -AsSecureString "  Mot de passe de l'utilisateur PostgreSQL '$DbUser'"
        $DbPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($saisie))
    }
    $octets = New-Object byte[] 48
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($octets)
    $cle = [Convert]::ToBase64String($octets)
    $lignes = @(
        '# Genere par setup.ps1 - fichier prive, ignore par Git.',
        "CASAFAMI_DB_PASSWORD=$DbPassword",
        "CASAFAMI_JWT_SECRET=$cle",
        "CASAFAMI_DB_URL=jdbc:postgresql://${DbHost}:${DbPort}/${DbName}",
        "CASAFAMI_DB_USER=$DbUser"
    )
    if ($AdminEmail -and $AdminPassword) {
        $lignes += "CASAFAMI_SUPER_ADMIN_EMAIL=$AdminEmail"
        $lignes += "CASAFAMI_SUPER_ADMIN_PASSWORD=$AdminPassword"
    }
    [IO.File]::WriteAllLines((Join-Path $PSScriptRoot $config), $lignes, (New-Object Text.UTF8Encoding($false)))
    Write-Host "  $config cree"
    if (-not ($AdminEmail -and $AdminPassword)) { Write-Host '  Pensez a creer le premier super administrateur : voir backend\cabinet\ADMIN_SETUP.md' -ForegroundColor Yellow }
}

# ---------------------------------------------------------------- 4. base de données
Etape 4 'Base de donnees PostgreSQL'
if ($psql -and $DbPassword) {
    $env:PGPASSWORD = $DbPassword
    $existe = & psql -h $DbHost -p $DbPort -U $DbUser -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DbName'" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  Connexion a PostgreSQL impossible (serveur arrete ? mot de passe ?). Creez la base a la main puis relancez.' -ForegroundColor Yellow
    } elseif ($existe -eq '1') {
        Write-Host "  base '$DbName' existe deja"
    } else {
        & psql -h $DbHost -p $DbPort -U $DbUser -d postgres -c "CREATE DATABASE `"$DbName`" ENCODING 'UTF8' TEMPLATE template0" | Out-Null
        Write-Host "  base '$DbName' creee (les tables se creent toutes seules au premier demarrage)"
    }
    Remove-Item Env:PGPASSWORD
} else {
    Write-Host "  etape ignoree (psql ou mot de passe absent) : CREATE DATABASE $DbName ENCODING 'UTF8';" -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 5. dépendances
Etape 5 'Dependances du site et du serveur'
Push-Location frontend
npm ci
if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'npm ci a echoue' }
Pop-Location
if ($SkipBuild) {
    Write-Host '  compilation du serveur ignoree (-SkipBuild) : elle se fera au premier lancement'
} else {
    Push-Location backend\cabinet
    & .\mvnw.cmd -q -DskipTests package
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'La compilation du serveur a echoue' }
    Pop-Location
    Write-Host '  serveur compile'
}

Write-Host "`nTermine. Pour lancer CASAFAMI : .\dev.ps1   (site : http://localhost:5173 - serveur : http://localhost:8080)" -ForegroundColor Green
