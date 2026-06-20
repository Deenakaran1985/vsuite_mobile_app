import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/instance_provider.dart';
import '../../core/services/biometric_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  final _bio = BiometricService();
  bool _bioRequired = false;
  bool _bioFailed   = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    final provider = context.read<InstanceProvider>();
    final nav      = Navigator.of(context);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    await provider.init();
    if (!mounted) return;
    if (!provider.hasInstances) {
      nav.pushReplacementNamed('/add-instance');
      return;
    }
    final enabled   = await _bio.isEnabled();
    final available = enabled ? await _bio.isAvailable() : false;
    if (enabled && available) {
      setState(() => _bioRequired = true);
      await _tryBiometric(nav);
    } else {
      nav.pushReplacementNamed('/dashboard');
    }
  }

  Future<void> _tryBiometric(NavigatorState nav) async {
    setState(() => _bioFailed = false);
    final ok = await _bio.authenticate(reason: 'Verify your identity to open VSuite');
    if (!mounted) return;
    if (ok) {
      nav.pushReplacementNamed('/dashboard');
    } else {
      setState(() => _bioFailed = true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/logo1.jpg', width: 100, height: 100, fit: BoxFit.cover),
              ),
              const SizedBox(height: 28),
              const Text(
                'VSuite',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
              const SizedBox(height: 6),
              Text(
                'Document Approval Portal',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, letterSpacing: 0.5),
              ),
              const SizedBox(height: 48),
              if (!_bioRequired)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                )
              else ...[
                Icon(
                  Icons.fingerprint,
                  color: _bioFailed ? Colors.redAccent : Colors.white70,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _bioFailed ? 'Authentication failed. Try again.' : 'Verify your identity',
                  style: TextStyle(
                    color: _bioFailed ? Colors.redAccent : Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _tryBiometric(Navigator.of(context)),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
