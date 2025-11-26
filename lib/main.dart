import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <<< CHYBĚJÍCÍ IMPORT PŘIDÁN
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Načtení .env
  await dotenv.load(fileName: ".env");
  
  // 2. Inicializace Supabase
  final Future<void> initialization = Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  
  // Spustíme aplikaci, ale obalíme ji do FutureBuilder, který počká na inicializaci
  runApp(
    FutureBuilder(
      future: initialization,
      builder: (context, snapshot) {
        // Zobrazíme Loading, dokud se Supabase neinicializuje
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.teal),
              ),
            ),
          );
        }

        // Pokud je inicializace hotová, spustíme App (a AuthGuard už Supabase najde)
        return const App();
      },
    ),
  );
}