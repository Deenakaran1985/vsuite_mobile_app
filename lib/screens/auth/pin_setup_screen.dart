import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pin_service.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pin  = PinService();
  String _first   = '';
  String _confirm = '';
  bool   _confirming = false;
  String _error = '';

  void _press(String digit) {
    setState(() { _error = ''; });
    if (!_confirming) {
      if (_first.length >= 6) return;
      setState(() => _first += digit);
      if (_first.length == 4) setState(() => _confirming = true);
    } else {
      if (_confirm.length >= 6) return;
      setState(() => _confirm += digit);
      if (_confirm.length == 4) _save();
    }
  }

  void _delete() {
    setState(() {
      _error = '';
      if (_confirming) {
        if (_confirm.isNotEmpty) {
          _confirm = _confirm.substring(0, _confirm.length - 1);
        } else {
          _confirming = false;
        }
      } else if (_first.isNotEmpty) {
        _first = _first.substring(0, _first.length - 1);
      }
    });
  }

  Future<void> _save() async {
    if (_first != _confirm) {
      setState(() { _confirm = ''; _error = 'PINs do not match. Try again.'; });
      return;
    }
    await _pin.setPin(_first);
    if (!mounted) return;
    Fluttertoast.showToast(
      msg: 'PIN set successfully!',
      backgroundColor: AppColors.success,
      textColor: Colors.white,
    );
    Navigator.pop(context, true);
  }

  String get _current => _confirming ? _confirm : _first;
  String get _label   => _confirming ? 'Confirm your PIN' : 'Create a 4-digit PIN';

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
            const Icon(Icons.lock_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(_label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18, height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _current.length ? Colors.white : Colors.white24,
                  border: Border.all(color: Colors.white54),
                ),
              )),
            ),

            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],

            const SizedBox(height: 36),
            _numpad(),

            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _numpad() {
    const keys = [['1','2','3'],['4','5','6'],['7','8','9'],['','0','⌫']];
    return Column(
      children: keys.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((k) => GestureDetector(
          onTap: () {
            if (k == '⌫') { _delete(); return; }
            if (k.isNotEmpty) _press(k);
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
        )).toList(),
      )).toList(),
    );
  }
}
