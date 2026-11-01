import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const RechtschreibApp());
}

class RechtschreibApp extends StatelessWidget {
  const RechtschreibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rechtschreib-Trainer 5. Klasse',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DiktatScreen(),
    );
  }
}

class LernWort {
  final String wort;
  final String beispielsatz;
  final String kategorie;

  const LernWort({
    required this.wort,
    required this.beispielsatz,
    required this.kategorie,
  });

  factory LernWort.fromJson(Map<String, dynamic> json) {
    return LernWort(
      wort: json['wort'] ?? '',
      beispielsatz: json['beispielsatz'] ?? '',
      kategorie: json['kategorie'] ?? 'Allgemein',
    );
  }
}

class DiktatScreen extends StatefulWidget {
  const DiktatScreen({super.key});

  @override
  State<DiktatScreen> createState() => _DiktatScreenState();
}

class _DiktatScreenState extends State<DiktatScreen> {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _controller = TextEditingController();

  // Ersetze diesen Link später mit deiner GitHub Raw-URL
  final String _jsonUrl =
      'https://raw.githubusercontent.com/dein-user/dein-repo/main/lernwoerter_klasse5.json';

  List<LernWort> _woerter = [];
  bool _isLoading = true;
  String? _errorMessage;

  int _currentIndex = 0;
  String? _feedbackMessage;
  bool? _isCorrect;

  // --- NEU: Fehler-Management Variablen ---
  final List<LernWort> _fehlerWoerter = [];
  bool _isWiederholungsModus = false;
  int _fehlerIndex = 0;
  // ----------------------------------------

  @override
  void initState() {
    super.initState();
    _initTts();
    _fetchWoerter();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
  }

  Future<void> _fetchWoerter() async {
    try {
      final response = await http.get(Uri.parse(_jsonUrl));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _woerter = jsonList.map((json) => LernWort.fromJson(json)).toList();
          _isLoading = false;
        });
        if (_woerter.isNotEmpty) _playWort();
      } else {
        throw Exception();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Online-Laden fehlgeschlagen. Notfall-Liste aktiv.';
        _woerter = const [
          LernWort(wort: 'Schifffahrt', beispielsatz: 'Die Schifffahrt auf dem Rhein war spannend.', kategorie: 'Konsonant'),
          LernWort(wort: 'großartig', beispielsatz: 'Du hast ein großartiges Ergebnis erzielt.', kategorie: 'ss/ß'),
        ];
        _isLoading = false;
      });
      if (_woerter.isNotEmpty) _playWort();
    }
  }

  // Hilfsmethode: Holt das aktuell aktive Wort (entweder normal oder aus der Fehlerliste)
  LernWort get _aktuellesWort {
    if (_isWiederholungsModus) {
      return _fehlerWoerter[_fehlerIndex];
    }
    return _woerter[_currentIndex];
  }

  Future<void> _playWort() async {
    if (_woerter.isEmpty) return;
    final aktuel = _aktuellesWort;
    await _tts.speak('Das Wort heißt: ${aktuel.wort}.${aktuel.beispielsatz}');
  }

  Future<void> _playNurWort() async {
    if (_woerter.isEmpty) return;
    await _tts.speak(_aktuellesWort.wort);
  }

  void _prufeEingabe() {
    final eingabe = _controller.text.trim();
    final zielWort = _aktuellesWort.wort;

    setState(() {
      if (eingabe == zielWort) {
        _isCorrect = true;
        _feedbackMessage = 'Richtig! Gut gemacht.';
      } else {
        _isCorrect = false;
        _feedbackMessage = 'Leider falsch. Richtig: "$zielWort"';
        
        // Wort zur Fehlerliste hinzufügen, falls noch nicht enthalten und im Normalmodus
        if (!_isWiederholungsModus && !_fehlerWoerter.contains(_aktuellesWort)) {
          _fehlerWoerter.add(_aktuellesWort);
        }
      }
    });
  }

  void _naechstesWort() {
    setState(() {
      _controller.clear();
      _feedbackMessage = null;
      _isCorrect = null;

      if (!_isWiederholungsModus) {
        // Normaler Durchgang
        if (_currentIndex < _woerter.length - 1) {
          _currentIndex++;
        } else {
          // Normaler Durchgang fertig -> Prüfen, ob Fehler existieren
          if (_fehlerWoerter.isNotEmpty) {
            _isWiederholungsModus = true;
            _fehlerIndex = 0;
          } else {
            _currentIndex = -1; // Alles fehlerfrei geschafft!
          }
        }
      } else {
        // Fehler-Modus Durchgang
        if (_fehlerIndex < _fehlerWoerter.length - 1) {
          _fehlerIndex++;
        } else {
          _fehlerWoerter.clear();
          _isWiederholungsModus = false;
          _currentIndex = -1; // Fertig
        }
      }
    });

    if (_currentIndex != -1 || _isWiederholungsModus) {
      _playWort();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Wenn der gesamte Durchgang komplett beendet ist
    if (_currentIndex == -1 && !_isWiederholungsModus) {
      return Scaffold(
        appBar: AppBar(title: const Text('Geschafft!')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('Großartig! Alle Wörter gemeistert.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                    _fehlerWoerter.clear();
                    _isWiederholungsModus = false;
                  });
                  _playWort();
                },
                child: const Text('Noch einmal üben'),
              ),
            ],
          ),
        ),
      );
    }

    final aktuel = _aktuellesWort;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isWiederholungsModus 
            ? 'Fehler-Training (${_fehlerIndex + 1}/${_fehlerWoerter.length})' 
            : 'Wort ${_currentIndex + 1} von${_woerter.length}'),
        backgroundColor: _isWiederholungsModus ? Colors.orange.shade100 : null,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.orange, fontSize: 12), textAlign: TextAlign.center),
              ),
            Chip(
              label: Text(aktuel.kategorie),
              backgroundColor: _isWiederholungsModus ? Colors.orange.shade50 : Colors.indigo.shade50,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _playWort,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Ganzes Diktat'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _playNurWort,
                  icon: const Icon(Icons.replay),
                  label: const Text('Nur Wort'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _prufeEingabe(),
              decoration: const InputDecoration(
                labelText: 'Lernwort eintippen',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _prufeEingabe,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isWiederholungsModus ? Colors.orange : Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: const Text('Prüfen', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 24),
            if (_feedbackMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isCorrect! ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isCorrect! ? Colors.green : Colors.red),
                ),
                child: Text(
                  _feedbackMessage!,
                  textAlign: TextAlign.center,
                  style: