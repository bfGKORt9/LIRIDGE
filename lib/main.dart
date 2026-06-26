import 'package:flutter/material.dart';
import 'security_gateway.dart';
import 'gemini_live_service.dart';
import 'audio_playback_service.dart';
import 'audio_pipeline_controller.dart';

void main() {
  runApp(const LiridgeApp());
}

class LiridgeApp extends StatelessWidget {
  const LiridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LIRIDGE CORE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          primary: const Color(0xFF00E5FF),
          secondary: const Color(0xFF39FF14),
        ),
      ),
      // アプリ起動時の最初の画面を「防壁」に設定
      home: const SecurityGateway(),
    );
  }
}

class LiridgeTerminalPage extends StatefulWidget {
  const LiridgeTerminalPage({super.key});
  @override
  State<LiridgeTerminalPage> createState() => _LiridgeTerminalPageState();
}

class _LiridgeTerminalPageState extends State<LiridgeTerminalPage> {
  late final GeminiLiveService _geminiService;
  late final AudioPlaybackService _audioService;
  late final AudioPipelineController _pipelineController;

  final TextEditingController _apiKeyController = TextEditingController();
  bool _isConnecting = false;
  bool _isConnected = false;
  final List<String> _consoleLogs = [];

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiLiveService();
    _audioService = AudioPlaybackService();
    _pipelineController = AudioPipelineController(
      geminiService: _geminiService,
      audioService: _audioService,
    );
    _addLog('LIRIDGE OS SYSTEM BOOT: STATUS OPERATIONAL');
    _addLog('AWAITING API KEY AUTHORIZATION...');
  }

  void _addLog(String msg) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _consoleLogs.add('[$timestamp] $msg');
    });
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      _addLog('INITIATING SHUTDOWN SEQUENCE...');
      _pipelineController.shutdown();
      setState(() => _isConnected = false);
      _addLog('CORE PIPELINE OFFLINE.');
    } else {
      final apiKey = _apiKeyController.text.trim();
      if (apiKey.isEmpty) {
        _addLog('ERROR: API KEY IS REQUIRED TO ESTABLISH LINK.');
        return;
      }
      setState(() => _isConnecting = true);
      _addLog('LAUNCHING BI-DIRECTIONAL AUDIO PIPELINE...');
      try {
        await _pipelineController.initialize(apiKey);
        setState(() => _isConnected = true);
        _addLog('LINK ESTABLISHED. VOICE TRANSMISSION READY.');
      } catch (e) {
        _addLog('CRITICAL REJECTION: LINK FAILED -> $e');
      } finally {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  void dispose() {
    _pipelineController.shutdown();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'LIRIDGE TERMINAL v1.0',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [Shadow(color: theme.colorScheme.primary, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
              decoration: InputDecoration(
                labelText: 'GEMINI API KEY',
                labelStyle: TextStyle(color: theme.colorScheme.primary.withOpacity(0.7)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  border: Border.all(
                    color: _isConnected ? theme.colorScheme.secondary.withOpacity(0.5) : theme.colorScheme.primary.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  itemCount: _consoleLogs.length,
                  itemBuilder: (context, index) {
                    final log = _consoleLogs[index];
                    final isError = log.contains('ERROR') || log.contains('CRITICAL');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isError ? Colors.redAccent : (_isConnected ? theme.colorScheme.secondary : Colors.cyanAccent),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isConnecting ? null : _toggleConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isConnected ? Colors.red.withOpacity(0.3) : theme.colorScheme.primary.withOpacity(0.2),
                side: BorderSide(color: _isConnected ? Colors.red : theme.colorScheme.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isConnecting
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Text(
                      _isConnected ? 'DISCONNECT LINK' : 'ESTABLISH NEURAL LINK',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: _isConnected ? Colors.redAccent : theme.colorScheme.primary,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
