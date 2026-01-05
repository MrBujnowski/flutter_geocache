import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../settings/application/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  static const routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení'),
        backgroundColor: Colors.teal,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Vzhled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Světlý režim'),
            value: ThemeMode.light,
            groupValue: settings.themeMode,
            onChanged: (value) => settings.updateThemeMode(value!),
            activeColor: Colors.teal,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Tmavý režim'),
            value: ThemeMode.dark,
            groupValue: settings.themeMode,
            onChanged: (value) => settings.updateThemeMode(value!),
            activeColor: Colors.teal,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Systémové nastavení'),
            value: ThemeMode.system,
            groupValue: settings.themeMode,
            onChanged: (value) => settings.updateThemeMode(value!),
            activeColor: Colors.teal,
          ),
          const Divider(),
          // Placeholder pro další nastavení (zvuky, jazyk atd.)
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Zvuky (v přípravě)'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
