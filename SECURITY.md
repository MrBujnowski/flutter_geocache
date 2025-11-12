# Bezpečnostní pokyny

## ⚠️ DŮLEŽITÉ: Ochrana API klíčů

### Co NIKDY necommitovat do Git:

1. **`.env` soubor** - obsahuje vaše API klíče
   - ✅ Je v `.gitignore`
   - ✅ Nikdy ho necommitovat!

2. **`web/index.html` s API klíčem** - pokud obsahuje skutečný API klíč místo placeholderu
   - ⚠️ Před commitem zkontrolujte, že obsahuje `YOUR_GOOGLE_MAPS_API_KEY_HERE`
   - ✅ Skript `setup_web_maps.py` nahradí placeholder při buildu

3. **Android/iOS konfigurační soubory s API klíči**
   - ✅ Používají placeholdery `YOUR_GOOGLE_MAPS_API_KEY_HERE`
   - ✅ Skripty je nahradí při buildu

### Jak to funguje:

1. **Vývoj:**
   - API klíč je v `.env` (není v gitu)
   - Konfigurační soubory obsahují placeholdery
   - Před spuštěním spusťte skripty, které nahradí placeholdery

2. **Build:**
   - Skripty načtou API klíč z `.env`
   - Nahradí placeholdery v konfiguračních souborech
   - Vygenerované soubory se používají pro build

3. **Git:**
   - Do gitu jdou pouze soubory s placeholdery
   - Skutečné API klíče zůstávají v `.env` (mimo git)

### Před commitem vždy zkontrolujte:

```bash
# Zkontrolujte, že .env není v gitu
git status .env

# Zkontrolujte web/index.html - měl by obsahovat placeholder
grep "YOUR_GOOGLE_MAPS_API_KEY_HERE" web/index.html

# Pokud najdete skutečný API klíč, obnovte placeholder:
python scripts/setup_web_maps.py --reset  # (pokud by existoval)
# Nebo ručně nahraďte API klíč placeholderem
```

### Pokud jste náhodou commitli API klíč:

1. **Okamžitě** zrušte API klíč v Google Cloud Console
2. Vytvořte nový API klíč
3. Aktualizujte `.env` soubor
4. Odstraňte API klíč z git historie (pokud je to možné)

### Bezpečnostní best practices:

- ✅ Používejte placeholdery v konfiguračních souborech
- ✅ API klíč uchovávejte pouze v `.env`
- ✅ `.env` je v `.gitignore`
- ✅ Před commitem vždy zkontrolujte změny
- ✅ Používejte omezení API klíčů v Google Cloud Console
- ✅ Pro produkci používejte samostatné API klíče s přísnými omezeními

