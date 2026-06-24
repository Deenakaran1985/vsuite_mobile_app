import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/instance_provider.dart';
import '../../core/providers/vmrfdu_provider.dart';

/// Entry point after splash — lets the user choose which VSuite app to open,
/// or jumps straight in if a session is already active.
class AppSelectionScreen extends StatelessWidget {
  const AppSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vmrfdu   = context.watch<VmrfduProvider>();
    final instance = context.watch<InstanceProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────────
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/images/logo1.jpg', width: 72, height: 72, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
                const Text(
                  'VSuite Mobile',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const Text(
                  'Select an application to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 40),

                // ── VMRFDU Hub card ──────────────────────────────────────────
                _AppCard(
                  logo: 'assets/images/vmrfdu.jpg',
                  title: 'VMRFDU V-Suite',
                  subtitle: 'Tickets & Postal Management',
                  serverLabel: VmrfduProvider.hubUrl,
                  badgeLabel: vmrfdu.isLoggedIn ? 'Signed in as ${vmrfdu.user?['name'] ?? ''}' : null,
                  badgeColor: Colors.green,
                  primaryColor: const Color(0xFF1A237E),
                  onTap: () {
                    if (vmrfdu.isLoggedIn) {
                      Navigator.pushReplacementNamed(context, '/vmrfdu-dashboard');
                    } else {
                      Navigator.pushNamed(context, '/vmrfdu-login');
                    }
                  },
                  buttonLabel: vmrfdu.isLoggedIn ? 'Open Dashboard' : 'Sign In',
                ),

                const SizedBox(height: 20),

                // ── V-Suite Instance card ────────────────────────────────────
                _AppCard(
                  logo: 'assets/images/logo1.jpg',
                  title: 'V-Suite (VIMW)',
                  subtitle: 'Document Approval & Chairman Actions',
                  serverLabel: 'http://14.139.184.39:8101',
                  badgeLabel: instance.hasInstances
                      ? '${instance.instances.length} instance${instance.instances.length > 1 ? 's' : ''} configured'
                      : null,
                  badgeColor: AppColors.accent,
                  primaryColor: AppColors.primary,
                  onTap: () {
                    if (instance.hasInstances) {
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    } else {
                      Navigator.pushNamed(context, '/add-instance');
                    }
                  },
                  buttonLabel: instance.hasInstances ? 'Open Dashboard' : 'Add Instance',
                ),

                const Spacer(),

                const Text(
                  'VMR Foundation of Dhanalakshmi\nUniversity – V-Suite Platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final String logo;
  final String title;
  final String subtitle;
  final String serverLabel;
  final String? badgeLabel;
  final Color? badgeColor;
  final Color primaryColor;
  final VoidCallback onTap;
  final String buttonLabel;

  const _AppCard({
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.serverLabel,
    required this.primaryColor,
    required this.onTap,
    required this.buttonLabel,
    this.badgeLabel,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 4,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(logo, width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    if (badgeLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? Colors.green).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: TextStyle(fontSize: 10, color: badgeColor ?? Colors.green, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(serverLabel, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(buttonLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
