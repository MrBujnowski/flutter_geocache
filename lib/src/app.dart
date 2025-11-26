import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importy tvých vlastních souborů
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/map/presentation/map_screen.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/auth/presentation/auth_screen.dart';

class App extends StatelessWidget {
const App({super.key});

@override
Widget build(BuildContext context) {
// POZNÁMKA: AppTheme musela být vytvořena samostatně
// Používáme zde jen placeholder pro Theme, pokud není definován AppTheme.
final lightTheme = ThemeData.light(useMaterial3: true);
final darkTheme = ThemeData.dark(useMaterial3: true);

return MaterialApp(
  title: 'GeoHunt',
  debugShowCheckedModeBanner: false,
  
  // Předpokládáme, že AppTheme existuje a nastavuje se správně
  theme: lightTheme, // Zde by mělo být AppTheme.lightTheme
  darkTheme: darkTheme, // Zde by mělo být AppTheme.darkTheme
  themeMode: ThemeMode.dark, // Používáme tmavý režim pro naši aplikaci
  
  // Místo initialRoute definujeme "router" - home je náš hlídač
  home: const AuthGuard(), 

  // Definovány trasy pro volání přes Navigator.pushNamed
  routes: {
    SplashScreen.routeName: (context) => const SplashScreen(),
    MapScreen.routeName: (context) => const MapScreen(),
    GameScreen.routeName: (context) => const GameScreen(),
    AuthScreen.routeName: (context) => const AuthScreen(),
  },
);


}
}

// Speciální widget pro kontrolu autentizace
class AuthGuard extends StatelessWidget {
const AuthGuard({super.key});

// Stream, který sleduje, zda se uživatel přihlásil/odhlásil
Stream<AuthState> get _authStream => Supabase.instance.client.auth.onAuthStateChange;

@override
Widget build(BuildContext context) {
// Sledujeme stav Supabase
return StreamBuilder<AuthState>(
stream: _authStream,
builder: (context, snapshot) {

    // Stav 1: Čekání na první stav Auth po inicializaci
    if (snapshot.connectionState == ConnectionState.waiting) {
        // Místo SplashScreenu (který má časovač) zobrazíme jen loading
        return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: Colors.teal),
            ),
        );
    }

    // Stav 2: Kontrola, zda je uživatel přihlášen (session je platná)
    final bool isSignedIn = snapshot.data?.session?.user != null;

    if (isSignedIn) {
      // Pokud je přihlášen, jdeme rovnou na Mapu
      return const MapScreen();
    } else {
      // Pokud není přihlášen, jdeme na Login obrazovku
      return const AuthScreen();
    }
  },
);


}
}