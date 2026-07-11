// ignore_for_file: type=lint
import 'package:flutter/material.dart'; // 【修正】大文字のIを小文字に修正
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'main.dart';

class SecurityGateway extends StatefulWidget {
  const SecurityGateway({super.key});

  @override
  State<SecurityGateway> createState() => _SecurityGatewayState();
}

class _SecurityGatewayState extends State<SecurityGateway> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isAccessDenied = false;
  bool _isScanning = false;
  int _failedAttempts = 0;
  final String _validCode = "LIRIDGE-06-ALPHA";

  @override
  void initState() {
    super.initState();
    _triggerBiometricScan();
  }

  Future<void> _triggerBiometricScan() async {
    setState(() => _isScanning = true);
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'VERIFY BIOMETRICS TO ACCESS CORE',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (didAuthenticate) {
          _grantAccess();
        } else {
          setState(() {
            _isAccessDenied = true;
            _isScanning = false;
          });
        }
      } else {
        setState(() => _isScanning = false); 
      }
    } catch (e) {
      setState(() {
        _isAccessDenied = true;
        _isScanning = false;
      });
    }
  }

  Future<void> _verifyManualCode() async {
    final input = _codeController.text.trim();
    if (input == _validCode) {
      _grantAccess();
    } else {
      setState(() {
        _isAccessDenied = true;
        _failedAttempts++;
        _codeController.clear();
      });
      if (_failedAttempts >= 3) {
        FocusScope.of(context).unfocus();
      }
    }
  }

  Future<void> _grantAccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_authorized', true);
    if (!mounted) return;
    
    // 【修正】最新のメインUI（UIRouter）へ接続先を更新
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const UIRouter()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isScanning ? Icons.document_scanner : Icons.fingerprint,
                size: 80,
                color: _isAccessDenied ? Colors.redAccent : const Color(0xFF39FF14),
              ),
              const SizedBox(height: 24),
              Text(
                _isScanning ? 'SCANNING BIOMETRICS...' : 'RESTRICTED AREA',
                style: TextStyle(
                  color: _isAccessDenied ? Colors.redAccent : const Color(0xFF39FF14),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 48),
              
              TextField(
                controller: _codeController,
                obscureText: true,
                enabled: _failedAttempts < 3,
                style: const TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'MANUAL OVERRIDE CODE',
                  labelStyle: TextStyle(color: const Color(0xFF00E5FF).withOpacity(0.7), letterSpacing: 2),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF39FF14)),
                  ),
                  disabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _failedAttempts < 3 ? _verifyManualCode : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: _isAccessDenied ? Colors.redAccent : const Color(0xFF00E5FF),
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                ),
                child: Text(
                  'EXECUTE OVERRIDE',
                  style: TextStyle(
                    color: _isAccessDenied ? Colors.redAccent : const Color(0xFF00E5FF),
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              if (_isAccessDenied) ...[
                const SizedBox(height: 24),
                Text(
                  'ACCESS DENIED. FAILED ATTEMPTS: $_failedAttempts/3',
                  style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
