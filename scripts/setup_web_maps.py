#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Skript pro nastavení Google Maps API klíče do web/index.html
Tento skript načte API klíč z .env souboru a vloží ho do web/index.html
"""

import os
import re
import sys
import io

# Nastavení UTF-8 encoding pro výstup
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def read_env_file():
    """Načte .env soubor a vrátí slovník s proměnnými"""
    env_vars = {}
    if not os.path.exists('.env'):
        print("❌ Soubor .env nebyl nalezen!")
        print("Vytvořte soubor .env s obsahem:")
        print("GOOGLE_MAPS_API_KEY=your_api_key_here")
        sys.exit(1)
    
    with open('.env', 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                env_vars[key.strip()] = value.strip()
    
    return env_vars

def update_web_index(api_key):
    """Aktualizuje web/index.html s API klíčem"""
    web_index_path = 'web/index.html'
    
    if not os.path.exists(web_index_path):
        print(f"❌ Soubor {web_index_path} nebyl nalezen!")
        return False
    
    with open(web_index_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Kontrola, zda už není Google Maps script přidán
    if re.search(r'maps\.googleapis\.com/maps/api/js', content):
        # Pokud už existuje, nahradíme API klíč (včetně prázdného klíče)
        content = re.sub(
            r'(maps\.googleapis\.com/maps/api/js\?key=)[^&"\']*',
            f'\\1{api_key}',
            content
        )
        print("🔄 Aktualizován existující Google Maps script s novým API klíčem")
    else:
        # Pokud neexistuje, přidáme nový script tag před </head>
        maps_script = f'  <!-- Google Maps JavaScript API -->\n  <script src="https://maps.googleapis.com/maps/api/js?key={api_key}&libraries=places"></script>\n'
        content = content.replace('</head>', f'{maps_script}</head>')
        print("✅ Přidán Google Maps JavaScript API script do web/index.html")
    
    with open(web_index_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return True

def main():
    print("🔧 Nastavování Google Maps API klíče pro web...")
    
    # Načte .env soubor
    env_vars = read_env_file()
    
    if 'GOOGLE_MAPS_API_KEY' not in env_vars:
        print("❌ Proměnná GOOGLE_MAPS_API_KEY nebyla nalezena v .env souboru!")
        sys.exit(1)
    
    api_key = env_vars['GOOGLE_MAPS_API_KEY']
    
    if not api_key or api_key == 'your_api_key_here':
        print("❌ API klíč není nastaven v .env souboru!")
        print("Nastavte GOOGLE_MAPS_API_KEY=your_actual_api_key v .env souboru")
        sys.exit(1)
    
    print(f"🔑 Načten API klíč: {api_key[:10]}...")
    
    # Aktualizuje web/index.html
    if update_web_index(api_key):
        print("🎉 Google Maps API klíč byl úspěšně nastaven pro web!")
        print("Nyní můžete spustit aplikaci s: flutter run -d chrome")
    else:
        print("❌ Nepodařilo se aktualizovat web/index.html!")
        sys.exit(1)

if __name__ == '__main__':
    main()

