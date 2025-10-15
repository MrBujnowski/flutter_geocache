import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Načtení .env souboru
  await dotenv.load(fileName: ".env");
  
  runApp(const App());
}
