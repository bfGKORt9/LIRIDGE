import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const LiridgeApp());
}

class LiridgeApp extends StatelessWidget {
  const LiridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LIRIDGE CORE',
      theme: ThemeData.dark(),
      home: const UIRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class UIRouter extends StatefulWidget {
  const UIRouter({super.key});

  @override
  State<UIRouter> createState() => _UIRouterState();
}

class _UIRouterState extends State<UIRouter> {
  bool _isMenuOpen = false;
  int _uiMode = 0; 
  bool _ducking = true;
  bool _reading = false;
  bool _autoTap = false;
  double _volume = 80.0;

  void _toggleMenu() => setState(() => _isMenuOpen = !_isMenuOpen);
  void _switchUI() => setState(() => _uiMode = (_uiMode + 1) % 3);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double panelWidth = screenWidth > 450 ? 400 : screenWidth * 0.88;
    double tabWidth = 35;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < -200) setState(() => _isMenuOpen = true);
          else if (details.primaryVelocity! > 200) setState(() => _isMenuOpen = false);
        },
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.02),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(Icons.blur_on, size: 80, color: Colors.white38),
                  ),
                  const SizedBox(height: 24),
                  const Text("LIRIDGE SYSTEM", style: TextStyle(color: Colors.white60, letterSpacing: 6, fontSize: 20, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 8),
                  const Text("パネルを引き出すか、左へスワイプしてください", style: TextStyle(color: Colors.white30, fontSize: 11)),
                ],
              ),
            ),

            if (_isMenuOpen)
              GestureDetector(
                onTap: _toggleMenu,
                child: Container(color: Colors.black60),
              ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              top: 0, bottom: 0,
              right: _isMenuOpen ? 0 : -panelWidth,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleMenu,
                    child: Container(
                      width: tabWidth, height: 90,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                        side: BorderSide(color: Colors.white12),
                      ),
                      child: Icon(_isMenuOpen ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new, color: Colors.white54, size: 14),
                    ),
                  ),
                  SizedBox(
                    width: panelWidth,
                    child: CocpitConsole(
                      key: ValueKey("$_uiMode-$_ducking-$_reading-$_autoTap-$_volume"),
                      mode: _uiMode,
                      ducking: _ducking,
                      reading: _reading,
                      autoTap: _autoTap,
                      volume: _volume,
                      onDuckingChanged: (v) => setState(() => _ducking = v),
                      onReadingChanged: (v) => setState(() => _reading = v),
                      onAutoTapChanged: (v) => setState(() => _autoTap = v),
                      onVolumeChanged: (v) => setState(() => _volume = v),
                      onSwitchUI: _switchUI,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CocpitConsole extends StatelessWidget {
  final int mode;
  final bool ducking;
  final bool reading;
  final bool autoTap;
  final double volume;
  final ValueChanged<bool> onDuckingChanged;
  final ValueChanged<bool> onReadingChanged;
  final ValueChanged<bool> onAutoTapChanged;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onSwitchUI;

  const CocpitConsole({
    super.key, required this.mode, required this.ducking, required this.reading,
    required this.autoTap, required this.volume, required this.onDuckingChanged,
    required this.onReadingChanged, required this.onAutoTapChanged, required this.onVolumeChanged, required this.onSwitchUI,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = mode == 0 ? const Color(0xFF5A1212) : (mode == 1 ? const Color(0xFF0A1424) : const Color(0xFF2B160A));
    Color ledColor = mode == 0 ? const Color(0xFFFFD700) : (mode == 1 ? const Color(0xFFFF2A2A) : const Color(0xFFFF8800));
    String title = mode == 0 ? "Mary version" : (mode == 1 ? "KyouAya version" : "Connecting Global Communities");

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center, radius: 1.3,
                  colors: [bgColor, Colors.black.withOpacity(0.9)],
                ),
              ),
            ),
          ),
          if (mode == 0) ...[
            Positioned.fill(
              child: Opacity(
                opacity: 0.04,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                  itemBuilder: (context, index) => const Icon(Icons.favorite, color: Colors.white),
                ),
              ),
            ),
          ],
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("IRIDGE", style: TextStyle(fontSize: 26, fontWeight: FontWeight.black, color: ledColor, letterSpacing: 4)),
                          Text(title, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: ledColor.withOpacity(0.7))),
                        ],
                      ),
                      IconButton(icon: Icon(Icons.vibration, color: ledColor.withOpacity(0.6)), onPressed: onSwitchUI)
                    ],
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(
                                width: double.infinity, height: 120,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6ECC9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF6E5638), width: 4),
                                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
                                ),
                                child: CustomPaint(painter: VUMeterPainter(mode: mode, value: volume)),
                              ),

                              GestureDetector(
                                onPanUpdate: (details) {
                                  double delta = details.delta.dx - details.delta.dy;
                                  double newValue = (volume + delta).clamp(0.0, 100.0);
                                  onVolumeChanged(newValue);
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 175, height: 175,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: ledColor.withOpacity(0.35), blurRadius: 25, spreadRadius: 3)],
                                      ),
                                    ),
                                    Container(
                                      width: 155, height: 155,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black87, width: 2),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF8E8E93), Color(0xFF2C2C2E)],
                                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: CustomPaint(painter: MainDialPainter(mode: mode, value: volume)),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      child: Text("SET TO ${volume.toInt()}", style: TextStyle(fontSize: 10, color: ledColor, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                    )
                                  ],
                                ),
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildSwitch("DUCKING", ducking, onDuckingChanged, ledColor),
                                  _buildSwitch("READING", reading, onReadingChanged, ledColor),
                                  _buildSwitch("AUTO-TAP", autoTap, onAutoTapChanged, ledColor),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(String label, bool state, ValueChanged<bool> onChanged, Color ledColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => onChanged(!state),
          child: Container(
            width: 50, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF151517),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: CustomPaint(painter: ToggleSwitchPainter(mode: mode, isOn: state)),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 9, height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state ? ledColor : Colors.black54,
            boxShadow: state ? [BoxShadow(color: ledColor, blurRadius: 10, spreadRadius: 2)] : [],
          ),
        ),
      ],
    );
  }
}

class VUMeterPainter extends CustomPainter {
  final int mode; final double value;
  VUMeterPainter({required this.mode, required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 10);
    final radius = size.height - 5;

    final paint = Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (int i = 0; i <= 20; i++) {
      double angle = math.pi + (i * (math.pi / 20));
      double length = i % 5 == 0 ? 16.0 : 8.0;
      Offset start = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      Offset end = center + Offset(math.cos(angle) * (radius - length), math.sin(angle) * (radius - length));
      canvas.drawLine(start, end, paint);
    }

    if (mode == 0) {
      final p = Paint()..color = Colors.orange.withOpacity(0.06)..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2 + 15), 30, p);
    }

    final needle = Paint()..color = mode == 1 ? const Color(0xFFB71C1C) : const Color(0xFFE53935)..style = PaintingStyle.stroke..strokeWidth = 2.0;
    double targetAngle = math.pi + (value / 100 * math.pi);
    Offset needleEnd = center + Offset(math.cos(targetAngle) * (radius - 4), math.sin(targetAngle) * (radius - 4));
    canvas.drawLine(center, needleEnd, needle);

    canvas.drawCircle(center, 12, Paint()..color = const Color(0xFF2C2C2E));
    canvas.drawCircle(center, 5, Paint()..color = Colors.amber);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MainDialPainter extends CustomPainter {
  final int mode; final double value;
  MainDialPainter({required this.mode, required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2;
    double rotationAngle = (value / 100) * 2 * math.pi;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    if (mode == 0) {
      paint.color = const Color(0xFFFFD700).withOpacity(0.35);
      for (int i = 0; i < 30; i++) {
        double angle = (i * 2 * math.pi) / 30;
        final path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(18, -radius + 25, 0, -radius + 12)
          ..quadraticBezierTo(-18, -radius + 25, 0, 0);
        canvas.save();
        canvas.rotate(angle);
        canvas.drawPath(path, paint);
        canvas.restore();
      }
      canvas.drawCircle(Offset.zero, 20, paint..style = PaintingStyle.fill);
    } else if (mode == 1) {
      paint.color = const Color(0xFFF5CD79).withOpacity(0.4);
      for (int i = 0; i < 12; i++) {
        double angle = (i * 2 * math.pi) / 12;
        canvas.drawLine(Offset.zero, Offset(math.cos(angle) * (radius - 20), math.sin(angle) * (radius - 20)), paint);
      }
      canvas.drawCircle(Offset.zero, radius - 40, paint);
    } else {
      paint.color = Colors.white12;
      for (double r = 8; r < radius; r += 6) {
        canvas.drawCircle(Offset.zero, r, paint);
      }
      canvas.drawCircle(Offset(0, -radius + 15), 4, Paint()..color = const Color(0xFFFF8800));
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ToggleSwitchPainter extends CustomPainter {
  final int mode; final bool isOn;
  ToggleSwitchPainter({required this.mode, required this.isOn});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    double travel = isOn ? -18.0 : 18.0;
    final knob = Offset(center.dx, center.dy + travel);

    canvas.drawCircle(center, 14, Paint()..color = Colors.black);
    canvas.drawCircle(center, 12, Paint()..color = const Color(0xFF2C2C2E));

    final p = Paint()
      ..gradient = const LinearGradient(
        colors: [Color(0xFFE5E5EA), Color(0xFF8E8E93), Color(0xFF1C1C1E)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      );

    if (mode == 0) {
      final heart = Paint()..color = const Color(0xFFFFD700);
      final path = Path();
      path.moveTo(knob.dx, knob.dy + 6);
      path.cubicTo(knob.dx - 14, knob.dy - 12, knob.dx - 18, knob.dy - 24, knob.dx, knob.dy - 14);
      path.cubicTo(knob.dx + 18, knob.dy - 24, knob.dx + 14, knob.dy - 12, knob.dx, knob.dy + 6);
      canvas.drawPath(path, heart);
    } else if (mode == 1) {
      final feather = Paint()..color = const Color(0xFFD4AF37);
      canvas.drawOval(Rect.fromCenter(center: knob, width: 10, height: 28), feather);
      canvas.drawLine(knob + const Offset(0, -14), knob + const Offset(0, 14), Paint()..color = Colors.black38);
    } else {
      canvas.drawCircle(knob, 10, p);
      canvas.drawRect(Rect.fromCenter(center: Offset(center.dx, center.dy + (travel / 2)), width: 6, height: 22), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
