import 'package:flutter/material.dart';
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
        scaffoldBackgroundColor: const Color(0xFF0A0E17), // 深宇宙の黒
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF), // ネオンシアン
          primary: const Color(0xFF00E5FF),
          secondary: const Color(0xFF39FF14), // バイオルミネセンスグリーン
        ),
      ),
      home: const LiridgeTerminalPage(),
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
    // 各種コアモジュールのインスタンス化
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

  /// ニューラルネットワーク（Gemini Live API）への接続・切断シーケンス
  Future<void> _toggleConnection() async {
    if (_isConnected) {
      _addLog('INITIATING SHUTDOWN SEQUENCE...');
      _pipelineController.shutdown();
      setState(() {
        _isConnected = false;
      });
      _addLog('CORE PIPELINE OFFLINE.');
    } else {
      final apiKey = _apiKeyController.text.trim();
      if (apiKey.isEmpty) {
        _addLog('ERROR: API KEY IS REQUIRED TO ESTABLISH LINK.');
        return;
      }

      setState(() {
        _isConnecting = true;
      });
      _addLog('LAUNCHING BI-DIRECTIONAL AUDIO PIPELINE...');

      try {
        await _pipelineController.initialize(apiKey);
        setState(() {
          _isConnected = true;
        });
        _addLog('LINK ESTABLISHED. VOICE TRANSMISSION READY.');
      } catch (e) {
        _addLog('CRITICAL REJECTION: LINK FAILED -> $e');
      } finally {
        setState(() {
          _isConnecting = false;
        });
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
            // タイネルバナー（ネオンヘッダー）
            Text(
              'LIRIDGE TERMINAL v1.0',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: theme.colorScheme.primary, blurRadius: 10)
                ],
              ),
            ),
            const SizedBox(height: 20),

            // API KEY 入力スロット
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

            // メインコンソール（ログモニター）
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  border: Border.solid(
                    borderWidth: 1,
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
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: isError 
                            ? Colors.redAccent 
                            : (_isConnected ? theme.colorScheme.secondary : Colors.cyanAccent),
                      ),
                      child: Text(log),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // イグニッションボタン（接続・切断）
            ElevatedButton(
              onPressed: _isConnecting ? null : _toggleConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isConnected ? Colors.red.withOpacity(0.3) : theme.colorScheme.primary.withOpacity(0.2),
                side: BorderSide(color: _isConnected ? Colors.red : theme.colorScheme.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
