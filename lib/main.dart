import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const DiktatApp());
}

class DiktatApp extends StatelessWidget {
  const DiktatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rechtschreibe App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const DiktatScreen(),
    );
  }
}

class DiktatScreen extends StatefulWidget {
  const DiktatScreen({super.key});

  @override
  State<DiktatScreen> createState() => _DiktatScreenState();
}

class _DiktatScreenState extends State<DiktatScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController _controller = TextEditingController();

  List<dynamic> _woerter = [];
  int _currentIndex = 0;
  String _feedback = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadWords();
  }

  void _initTts() async {
    await flutterTts.setLanguage("de-DE");
    await flutterTts.setSpeechRate(0.4);
  }

  Future<void> _loadWords() async {
    try {
      final response = await http.get(Uri.parse('https://raw.githubusercontent.com/matthiasgampp-cyber/RechtschreibeApp/main/lernwoerter_klasse5.json'));
      if (response.statusCode == 200) {
        final List<dynamic> loaded = json.decode(response.body);
        if (loaded.isNotEmpty) {
          setState(() {
            _woerter = loaded;
            _isLoading = false;
          });
          _speakCurrentWord();
          return;
        }
      }
      _useFallbackWords();
    } catch (e) {
      _useFallbackWords();
    }
  }

  void _useFallbackWords() {
    setState(() {
      // Erweiterter, solider Grundwortschatz für Klasse 5
      _woerter = [
        {"wort": "Beispiel", "satz": "Das ist ein gutes Beispiel."},
        {"wort": "Schule", "satz": "Wir gehen gerne in die Schule."},
        {"wort": "Klassenzimmer", "satz": "Unser Klassenzimmer ist hell."},
        {"wort": "Ferien", "satz": "Die Ferien dauern sechs Wochen."},
        {"wort": "Hausaufgabe", "satz": "Die Hausaufgabe wird sorgfältig erledigt."},
        {"wort": "Wörterbuch", "satz": "Schlage das Wort im Wörterbuch nach."},
        {"wort": "Fahrrad", "satz": "Er fährt mit dem Fahrrad zur Schule."},
        {"wort": "Fragezeichen", "satz": "Am Ende des Satzes steht ein Fragezeichen."},
        {"wort": "Schreibtisch", "satz": "Auf dem Schreibtisch liegen Hefte."},
        {"wort": "Entschuldigung", "satz": "Sie bat höflich um Entschuldigung."},
        {"wort": "Wichtig", "satz": "Diese Information ist sehr wichtig."},
        {"wort": "Lieblingsfach", "satz": "Mathematik ist mein Lieblingsfach."}
      ];
      _isLoading = false;
    });
    if (_woerter.isNotEmpty) {
      _speakCurrentWord();
    }
  }

  void _speakCurrentWord() async {
    if (_woerter.isNotEmpty && _currentIndex < _woerter.length) {
      String wort = _woerter[_currentIndex]['wort'];
      await flutterTts.speak(wort);
    }
  }

  void _checkWord() {
    if (_woerter.isEmpty || _currentIndex >= _woerter.length) return;

    String eingabe = _controller.text.trim();
    String zielWort = _woerter[_currentIndex]['wort'];

    if (eingabe.toLowerCase() == zielWort.toLowerCase()) {
      setState(() {
        _controller.clear();
        if (_currentIndex < _woerter.length - 1) {
          _currentIndex++;
          _feedback = 'Richtig! Weiter geht es mit dem nächsten Wort.';
          _speakCurrentWord();
        } else {
          // Endlos-Schleife: Nach dem letzten Wort fängt es wieder von vorne an
          _currentIndex = 0;
          _feedback = 'Fantastisch! Du hast alle Wörter geschafft. Die nächste Runde beginnt!';
          _speakCurrentWord();
        }
      });
    } else {
      setState(() {
        _feedback = 'Leider falsch, versuche es noch einmal!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diktat-Trainer 5. Klasse'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Wort ${_currentIndex + 1} von ${_woerter.length}',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _speakCurrentWord,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Wort noch einmal hören'),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Gefordertes Wort eingeben',
                    ),
                    onSubmitted: (_) => _checkWord(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _checkWord,
                    child: const Text('Überprüfen'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _feedback,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: _feedback.startsWith('Richtig') || _feedback.startsWith('Fantastisch')
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}