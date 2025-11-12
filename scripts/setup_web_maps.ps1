# PowerShell skript pro nastavení Google Maps API klíče do web/index.html
# Tento skript načte API klíč z .env souboru a vloží ho do web/index.html

Write-Host "🔧 Nastavování Google Maps API klíče pro web..." -ForegroundColor Cyan

# Kontrola existence .env souboru
if (-not (Test-Path ".env")) {
    Write-Host "❌ Soubor .env nebyl nalezen!" -ForegroundColor Red
    Write-Host "Vytvořte soubor .env s obsahem:" -ForegroundColor Yellow
    Write-Host "GOOGLE_MAPS_API_KEY=your_api_key_here" -ForegroundColor Yellow
    exit 1
}

# Načtení .env souboru
$envContent = Get-Content ".env" -Raw
$apiKey = ""

# Parsování .env souboru
$lines = $envContent -split "`n"
foreach ($line in $lines) {
    $line = $line.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
        $parts = $line -split "=", 2
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        
        if ($key -eq "GOOGLE_MAPS_API_KEY") {
            $apiKey = $value
            break
        }
    }
}

# Kontrola API klíče
if (-not $apiKey -or $apiKey -eq "your_api_key_here") {
    Write-Host "❌ API klíč není nastaven v .env souboru!" -ForegroundColor Red
    Write-Host "Nastavte GOOGLE_MAPS_API_KEY=your_actual_api_key v .env souboru" -ForegroundColor Yellow
    exit 1
}

if ($apiKey.Length -gt 10) {
    Write-Host "🔑 Načten API klíč: $($apiKey.Substring(0, 10))..." -ForegroundColor Green
} else {
    Write-Host "🔑 Načten API klíč" -ForegroundColor Green
}

# Aktualizace web/index.html
$webIndexPath = "web/index.html"
if (-not (Test-Path $webIndexPath)) {
    Write-Host "❌ Soubor $webIndexPath nebyl nalezen!" -ForegroundColor Red
    exit 1
}

$webContent = Get-Content $webIndexPath -Raw

# Kontrola, zda už není Google Maps script přidán
if ($webContent -match "maps\.googleapis\.com/maps/api/js") {
    # Pokud už existuje, nahradíme API klíč
    $webContent = $webContent -replace "maps\.googleapis\.com/maps/api/js\?key=[^&`"']+", "maps.googleapis.com/maps/api/js?key=$apiKey"
    Write-Host "🔄 Aktualizován existující Google Maps script s novým API klíčem" -ForegroundColor Yellow
} else {
    # Pokud neexistuje, přidáme nový script tag před </head>
    $mapsScript = "  <!-- Google Maps JavaScript API -->`n  <script src=`"https://maps.googleapis.com/maps/api/js?key=$apiKey`&libraries=places`"></script>`n"
    $webContent = $webContent -replace "</head>", "$mapsScript</head>"
    Write-Host "✅ Přidán Google Maps JavaScript API script do web/index.html" -ForegroundColor Green
}

Set-Content $webIndexPath $webContent -Encoding UTF8

Write-Host "🎉 Google Maps API klíč byl úspěšně nastaven pro web!" -ForegroundColor Green
Write-Host "Nyní můžete spustit aplikaci s: flutter run -d chrome" -ForegroundColor Cyan

