# PowerShell skript pro nastavení Google Maps API klíče z .env souboru
# do AndroidManifest.xml a iOS Info.plist

Write-Host "🔧 Nastavování Google Maps API klíče..." -ForegroundColor Cyan

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

Write-Host "🔑 Načten API klíč: $($apiKey.Substring(0, [Math]::Min(10, $apiKey.Length)))..." -ForegroundColor Green

# Aktualizace AndroidManifest.xml
$androidManifestPath = "android/app/src/main/AndroidManifest.xml"
if (Test-Path $androidManifestPath) {
    $androidContent = Get-Content $androidManifestPath -Raw
    $androidContent = $androidContent -replace "YOUR_GOOGLE_MAPS_API_KEY_HERE", $apiKey
    Set-Content $androidManifestPath $androidContent -Encoding UTF8
    Write-Host "✅ AndroidManifest.xml aktualizován s API klíčem" -ForegroundColor Green
} else {
    Write-Host "❌ Soubor $androidManifestPath nebyl nalezen!" -ForegroundColor Red
}

# Aktualizace iOS Info.plist
$iosPlistPath = "ios/Runner/Info.plist"
if (Test-Path $iosPlistPath) {
    $iosContent = Get-Content $iosPlistPath -Raw
    $iosContent = $iosContent -replace "YOUR_GOOGLE_MAPS_API_KEY_HERE", $apiKey
    Set-Content $iosPlistPath $iosContent -Encoding UTF8
    Write-Host "✅ iOS Info.plist aktualizován s API klíčem" -ForegroundColor Green
} else {
    Write-Host "❌ Soubor $iosPlistPath nebyl nalezen!" -ForegroundColor Red
}

Write-Host "🎉 API klíče byly úspěšně nastaveny!" -ForegroundColor Green
Write-Host "Nyní můžete spustit aplikaci s: flutter run" -ForegroundColor Cyan
