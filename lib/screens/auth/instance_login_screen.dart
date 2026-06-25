import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/vsuite_instance.dart';
import '../../core/providers/instance_provider.dart';

/// Direct-login screen for a v-suite instance.
/// Called when a saved instance has no cached Bearer token yet.
class InstanceLoginScreen extends StatefulWidget {
  final VsuiteInstance instance;
  const InstanceLoginScreen({super.key, required this.instance});

  @override
  State<InstanceLoginScreen> createState() => _InstanceLoginScreenState();
}

class _InstanceLoginScreenState extends State<InstanceLoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill email from saved instance if available
    _emailCtl.text = widget.instance.email;
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final api = context.read<InstanceProvider>().api;
    final result = await api.instanceLogin(
      instanceUrl: widget.instance.url,
      email: _emailCtl.text.trim(),
      password: _passCtl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      final token = result['data']['token'] as String;
      final role  = result['data']['user']['role'] as String? ?? 'Staff';

      // Store token in instance provider
      await context.read<InstanceProvider>().storeInstanceToken(
        widget.instance.id, token, role,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Fluttertoast.showToast(
        msg: result['message'] as String? ?? 'Login failed',
        backgroundColor: AppColors.danger,
        textColor: Colors.white,
      );
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/logo1.jpg', width: 72, height: 72, fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.instance.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.instance.url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 32),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailCtl,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              hintText: 'username or email',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passCtl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
