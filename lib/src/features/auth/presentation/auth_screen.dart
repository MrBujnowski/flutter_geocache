import 'package:flutter/material.dart';
import 'package:flutter_geocache/src/features/auth/data/supabase_auth_repository.dart'; // Náš repozitář

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  static const String routeName = '/auth';

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final SupabaseAuthRepository _authRepository = SupabaseAuthRepository();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  
  bool _isLogin = true; // true = Login, false = Registrace
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- Přihlášení přes Google ---
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authRepository.signInWithGoogle();
      // Navigace se spustí automaticky přes Widget v App.dart
    } catch (e) {
      _showError('Chyba Google přihlášení: Zkontrolujte nastavení klíčů.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Přihlášení/Registrace emailem ---
  Future<void> _handleEmailAuth() async {
    setState(() => _isLoading = true);
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && username.isEmpty)) {
      _showError('Vyplňte všechna pole.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (_isLogin) {
        await _authRepository.signInWithEmail(email, password);
      } else {
        await _authRepository.signUpWithEmail(email, password, username);
        _showError('Registrace úspěšná! Zkontrolujte email pro potvrzení.');
        setState(() => _isLogin = true); // Po registraci přejít na Login
      }
    } catch (e) {
      _showError('Chyba: ${e.toString().split('message:').last.trim()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        title: Text(_isLogin ? 'Přihlášení' : 'Registrace'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- HESLO a EMAIL formulář ---
              Text(
                _isLogin ? 'Vítejte zpět v GeoHunt' : 'Vytvořte si účet',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              if (!_isLogin) ...[
                _buildTextField(_usernameController, 'Uživatelské jméno', Icons.person),
                const SizedBox(height: 16),
              ],
              
              _buildTextField(_emailController, 'Email', Icons.email),
              const SizedBox(height: 16),
              
              _buildTextField(_passwordController, 'Heslo', Icons.lock, isPassword: true),
              const SizedBox(height: 30),

              // --- TLAČÍTKO EMAIL AUTH ---
              ElevatedButton(
                onPressed: _isLoading ? null : _handleEmailAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isLogin ? 'Přihlásit se' : 'Zaregistrovat se',
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),

              const SizedBox(height: 20),

              // --- Oddělovač ---
              const Row(
                children: [
                  Expanded(child: Divider(color: Colors.white54)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('NEBO', style: TextStyle(color: Colors.white70)),
                  ),
                  Expanded(child: Divider(color: Colors.white54)),
                ],
              ),
              
              const SizedBox(height: 20),

              // --- TLAČÍTKO GOOGLE ---
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                  height: 24,
                  width: 24,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
                ),
                label: Text(
                  _isLogin ? 'Přihlásit se přes Google' : 'Registrace přes Google',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              
              const SizedBox(height: 40),

              // --- PŘEPÍNÁNÍ REŽIMU ---
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin ? 'Nemáš účet? Zaregistruj se' : 'Už máš účet? Přihlas se',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.tealAccent),
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
    );
  }
}