import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  static const String routeName = '/game';

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Cílový počet kliknutí
  static const int _targetClicks = 10;
  // Časový limit v sekundách
  static const int _timeLimitSeconds = 5;

  int _currentClicks = 0;
  int _remainingTime = _timeLimitSeconds;
  Timer? _timer;
  bool _gameStarted = false;
  bool _gameOver = false;
  bool _won = false;

  CacheModel? _cache;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Získání dat o cache z argumentů navigace
    if (_cache == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is CacheModel) {
        _cache = args;
      }
    }
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _currentClicks = 0;
      _remainingTime = _timeLimitSeconds;
      _gameOver = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _endGame(false);
        }
      });
    });
  }

  void _handleTap() {
    if (!_gameStarted || _gameOver) return;

    setState(() {
      _currentClicks++;
      if (_currentClicks >= _targetClicks) {
        _endGame(true);
      }
    });
  }

  void _endGame(bool success) {
    _timer?.cancel();
    setState(() {
      _gameOver = true;
      _won = success;
    });

    if (success) {
      // Počkáme chvilku, aby si uživatel užil vítězství, a pak se vrátíme
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          // Vrátíme 'true' jako výsledek hry
          Navigator.of(context).pop(true); 
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pokud nemáme data o cache, zobrazíme chybu
    if (_cache == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Chyba")),
        body: const Center(child: Text("Chybí data o cache!")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false), // Zrušení hry
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _won ? Icons.lock_open : Icons.lock,
                size: 80,
                color: _won ? Colors.green : Colors.amber,
              ),
              const SizedBox(height: 20),
              Text(
                "Odemknout: ${_cache!.displayName}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              if (!_gameStarted) ...[
                const Text(
                  "Máš 5 sekund na to, abys 10x klepnul na zámek a vypáčil ho!",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: const Text("START", style: TextStyle(fontSize: 20, color: Colors.white)),
                ),
              ] else ...[
                // Herní UI
                Text(
                  "Čas: $_remainingTime s",
                  style: TextStyle(
                    color: _remainingTime <= 2 ? Colors.red : Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: _currentClicks / _targetClicks,
                  backgroundColor: Colors.white24,
                  color: _won ? Colors.green : Colors.amber,
                  minHeight: 20,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 10),
                Text(
                  "$_currentClicks / $_targetClicks",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 40),
                
                if (_gameOver && !_won)
                  Column(
                    children: [
                      const Text(
                        "Čas vypršel!",
                        style: TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _startGame,
                        child: const Text("Zkusit znovu"),
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: _handleTap,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _won ? Colors.green : Colors.teal,
                        boxShadow: [
                          BoxShadow(
                            color: (_won ? Colors.green : Colors.teal).withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Icon(
                        _won ? Icons.check : Icons.fingerprint,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}