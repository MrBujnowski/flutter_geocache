import os

# Cesta k souborům
ENV_FILE = '.env'
INDEX_HTML_PATH = 'web/index.html'
PLACEHOLDER = 'GOOGLE_WEB_CLIENT_ID_PLACEHOLDER'
ENV_VARIABLE = 'GOOGLE_WEB_CLIENT_ID'

def get_env_variable(var_name):
    """Načte proměnnou z .env souboru."""
    try:
        with open(ENV_FILE, 'r') as f:
            for line in f:
                if line.strip().startswith(f'{var_name}='):
                    # Odstraní název proměnné a bílé znaky
                    return line.strip().split('=', 1)[1].strip()
    except FileNotFoundError:
        print(f"Chyba: Soubor {ENV_FILE} nebyl nalezen.")
        exit(1)
    return None

def inject_client_id():
    """Nahradí placeholder v index.html skutečným ID."""
    client_id = get_env_variable(ENV_VARIABLE)

    if not client_id or client_id == PLACEHOLDER:
        print("CHYBA: GOOGLE_WEB_CLIENT_ID nenalezen v .env nebo je prázdný.")
        return

    try:
        with open(INDEX_HTML_PATH, 'r') as f:
            content = f.read()

        new_content = content.replace(PLACEHOLDER, client_id)

        with open(INDEX_HTML_PATH, 'w') as f:
            f.write(new_content)
            
        print(f"INFO: GOOGLE_WEB_CLIENT_ID byl úspěšně vložen do {INDEX_HTML_PATH}")

    except FileNotFoundError:
        print(f"CHYBA: Soubor {INDEX_HTML_PATH} nebyl nalezen.")
    except Exception as e:
        print(f"CHYBA při zápisu: {e}")

if __name__ == "__main__":
    inject_client_id()