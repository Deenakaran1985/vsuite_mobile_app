import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/pin_service.dart';

class PinLockScreen extends StatefulWidget {
  final String destination;          // route to push on success
  final bool   allowBiometric;
  const PinLockScreen({
    super.key,
    this.destination = '/dashboard',
    this.allowBiometric = true,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _pin  = PinService();
  final _bio  = BiometricService();
  String _entered = '';
  String _error   = '';
  bool   _bioAvail = false;

  @override
  void initState() {
    super.initState();
    _initBio();
  }

  Future<void> _initBio() async {
    if (!widget.allowBiometric) return;
    final enabled   = await _bio.isEnabled();
    final available = enabled ? await _bio.isAvailable() : false;
    if (mounted) setState(() => _bioAvail = available && enabled);
    if (_bioAvail) _tryBio();
  }

  Future<void> _tryBio() async {
    final nav = Navigator.of(context);
    final ok = await _bio.authenticate(reason: 'Unlock VSuite');
    if (!mounted) return;
    if (ok) nav.pushReplacementNamed(widget.destination);
  }

  void _press(String digit) {
    if (_entered.length >= 6) return;
    setState(() { _entered += digit; _error = ''; });
    if (_entered.length == 4) _verify();   // auto-submit at 4 digits
  }

  void _delete() => setState(() {
    if (_entered.isNotEmpty) _entered = _entered.substring(0, _entered.length - 1);
    _error = '';
  });

  Future<void> _verify() async {
    final nav = Navigator.of(context);
    final ok = await _pin.verifyPin(_entered);
    if (!mounted) return;
    if (ok) {
      nav.pushReplacementNamed(widget.destination);
    } else {
      setState(() { _entered = ''; _error = 'Incorrect PIN. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/images/logo1.jpg', width: 64, height: 64, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            const Text('Enter PIN', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 32),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18, height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _entered.length ? Colors.white : Colors.white24,
                  border: Border.all(color: Colors.white54),
                ),
              )),
            ),

            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],

            const SizedBox(height: 36),

            // Numpad
            _numpad(),

            if (_bioAvail) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _tryBio,
                icon: const Icon(Icons.fingerprint, color: Colors.white70),
                label: const Text('Use Biometrics', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _numpad() {
    const keys = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['','0','⌫'],
    ];
    return Column(
      children: keys.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((k) => _key(k)).toList(),
      )).toList(),
    );
  }

  Widget _key(String k) => GestureDetector(
    onTap: () {
      if (k == '⌫') { _delete(); return; }
      if (k.isEmpty) return;
      _press(k);
    },
    child: Container(
      margin: const EdgeInsets.all(8),
      width: 70, height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: k.isEmpty ? Colors.transparent : Colors.white12,
        border: k.isEmpty ? null : Border.all(color: Colors.white24),
      ),
      alignment: Alignment.center,
      child: k == '⌫'
          ? const Icon(Icons.backspace_outlined, color: Colors.white70, size: 22)
          : Text(k, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
    ),
  );
}
