# Nastavení Google Maps API pro GeoHunt

## Krok 1: Vytvoření Google Cloud projektu

1. Jděte na [Google Cloud Console](https://console.cloud.google.com/)
2. Přihlaste se pomocí Google účtu
3. Klikněte na "Select a project" a pak "New Project"
4. Zadejte název projektu (např. "GeoHunt Maps")
5. Klikněte "Create"

## Krok 2: Povolení Google Maps API

1. V levém menu klikněte na "APIs & Services" > "Library"
2. Vyhledejte "Maps SDK for Android" a klikněte na něj
3. Klikněte "Enable"
4. Opakujte pro "Maps SDK for iOS" (pokud plánujete iOS verzi)

## Krok 3: Vytvoření API klíče

1. Jděte na "APIs & Services" > "Credentials"
2. Klikněte "Create Credentials" > "API Key"
3. Zkopírujte vytvořený API klíč

## Krok 4: Nastavení API klíče v .env souboru

1. Vytvořte soubor `.env` v kořenovém adresáři projektu
2. Přidejte do něj:
```
GOOGLE_MAPS_API_KEY=your_actual_api_key_here
```

**DŮLEŽITÉ:** Nahraďte `your_actual_api_key_here` vaším skutečným API klíčem!

## Krok 5: Automatické nastavení API klíče

### Pro Windows (PowerShell):
```powershell
.\scripts\setup_api_keys.ps1
```

### Pro Linux/Mac (Python):
```bash
python3 scripts/setup_api_keys.py
```

Tyto skripty automaticky:
- Načtou API klíč z `.env` souboru
- Nahradí placeholder v `AndroidManifest.xml`
- Nahradí placeholder v `iOS Info.plist`

## Krok 6: Omezení API klíče (doporučeno)

1. V Google Cloud Console jděte na "APIs & Services" > "Credentials"
2. Klikněte na váš API klíč
3. V sekci "Application restrictions" vyberte:
   - Pro Android: "Android apps" a přidejte SHA-1 fingerprint
   - Pro iOS: "iOS apps" a přidejte Bundle ID
4. V sekci "API restrictions" vyberte "Restrict key" a vyberte pouze Maps SDK

## Testování

Po nastavení API klíče:
1. Spusťte `flutter clean`
2. Spusťte `flutter pub get`
3. Spusťte aplikaci na zařízení (ne emulátoru pro GPS testování)

## Bezpečnost

- ✅ `.env` soubor je v `.gitignore` - nebude commitnut do Git
- ✅ API klíč se nastavuje automaticky ze `.env` souboru
- ✅ Placeholder se nahrazuje pouze při buildu
- ✅ Nikdo jiný než vy neuvidí váš API klíč

## Poznámky

- API klíč je zdarma do určitého limitu použití
- Pro produkční aplikaci vždy nastavte omezení API klíče
- Pokud změníte API klíč, spusťte skript znovu
