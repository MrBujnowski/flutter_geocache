#!/usr/bin/env python3
"""
Skript pro nastavení Google Maps API klíče z .env souboru
do AndroidManifest.xml a iOS Info.plist
"""

import os
import re
import sys

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

def update_android_manifest(api_key):
    """Aktualizuje AndroidManifest.xml s API klíčem"""
    manifest_path = 'android/app/src/main/AndroidManifest.xml'
    
    if not os.path.exists(manifest_path):
        print(f"❌ Soubor {manifest_path} nebyl nalezen!")
        return False
    
    with open(manifest_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Nahradí placeholder skutečným API klíčem
    updated_content = content.replace(
        'YOUR_GOOGLE_MAPS_API_KEY_HERE',
        api_key
    )
    
    with open(manifest_path, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    
    print(f"✅ AndroidManifest.xml aktualizován s API klíčem")
    return True

def update_ios_info_plist(api_key):
    """Aktualizuje iOS Info.plist s API klíčem"""
    plist_path = 'ios/Runner/Info.plist'
    
    if not os.path.exists(plist_path):
        print(f"❌ Soubor {plist_path} nebyl nalezen!")
        return False
    
    with open(plist_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Nahradí placeholder skutečným API klíčem
    updated_content = content.replace(
        'YOUR_GOOGLE_MAPS_API_KEY_HERE',
        api_key
    )
    
    with open(plist_path, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    
    print(f"✅ iOS Info.plist aktualizován s API klíčem")
    return True

def main():
    print("🔧 Nastavování Google Maps API klíče...")
    
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
    
    # Aktualizuje konfigurační soubory
    android_success = update_android_manifest(api_key)
    ios_success = update_ios_info_plist(api_key)
    
    if android_success and ios_success:
        print("🎉 API klíče byly úspěšně nastaveny!")
        print("Nyní můžete spustit aplikaci s: flutter run")
    else:
        print("❌ Některé soubory se nepodařilo aktualizovat!")
        sys.exit(1)

if __name__ == '__main__':
    main()
