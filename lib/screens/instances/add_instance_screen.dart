import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/vsuite_instance.dart';
import '../../core/providers/instance_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';

class AddInstanceScreen extends StatefulWidget {
  final VsuiteInstance? editing;
  const AddInstanceScreen({super.key, this.editing});

  @override
  State<AddInstanceScreen> createState() => _AddInstanceScreenState();
}

class _AddInstanceScreenState extends State<AddInstanceScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _urlCtl   = TextEditingController();
  final _userCtl  = TextEditingController();
  final _pwdCtl   = TextEditingController();

  bool _obscure  = true;
  bool _loading  = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _urlCtl.text  = widget.editing!.url;
      _userCtl.text = widget.editing!.email;
    }
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    _userCtl.dispose();
    _pwdCtl.dispose();
    super.dispose();
  }

  String _labelFromUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return uri.host.isNotEmpty ? uri.host : url.trim();
    } catch (_) {
      return url.trim();
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final url      = _urlCtl.text.trim();
    final username = _userCtl.text.trim();
    final password = _pwdCtl.text;

    final result = await ApiService(StorageService()).instanceLogin(
      instanceUrl: url,
      email:       username,
      password:    password,
    );

    if (!mounted) { setState(() => _loading = false); return; }

    if (result['success'] != true) {
      setState(() => _loading = false);
      Fluttertoast.showToast(
        msg: result['message'] as String? ?? 'Login failed. Check URL and credentials.',
        backgroundColor: AppColors.danger,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    // Login succeeded — save instance + token + role
    final token = result['data']['token'] as String;
    final role  = result['data']['user']['role'] as String? ?? 'Staff';
    final email = result['data']['user']['email'] as String? ?? username;

    final inst = VsuiteInstance(
      id:    widget.editing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: _labelFromUrl(url),
      url:   url,
      email: email,
    );

    final provider = context.read<InstanceProvider>();
    if (widget.editing == null) {
      await provider.addInstance(inst, password);
    } else {
      await provider.updateInstance(inst, newPassword: password);
    }
    await provider.storeInstanceToken(inst.id, token, role);

    setState(() => _loading = false);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/images/logo1.jpg', width: 80, height: 80, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Edit Instance' : 'Connect to V-Suite',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  isEdit ? 'Update connection details' : 'Enter your server URL and credentials',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
                ),
                const SizedBox(height: 32),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── URL ──────────────────────────────────────────
                          TextFormField(
                            controller:   _urlCtl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText:  'Server URL',
                              hintText:   'http://14.139.184.39:8101',
                              prefixIcon: Icon(Icons.link),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Server URL is required';
                              if (!v.trim().startsWith('http')) return 'URL must start with http:// or https://';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          // ── Username ──────────────────────────────────────
                          TextFormField(
                            controller:   _userCtl,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText:  'Username',
                              hintText:   'your.username or email',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                          ),
                          const SizedBox(height: 18),
                          // ── Password ──────────────────────────────────────
                          TextFormField(
                            controller:  _pwdCtl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText:  isEdit ? 'Password (leave blank to keep)' : 'Password',
                              hintText:   '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (!isEdit && (v == null || v.isEmpty)) return 'Password is required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          // ── Connect button ────────────────────────────────
                          ElevatedButton(
                            onPressed: _loading ? null : _connect,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    isEdit ? 'Save & Reconnect' : 'Connect',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                          ),
                          if (isEdit) ...[
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(context, '/select-app'),
                              child: const Text('← Back'),
                            ),
                          ],
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
    );
  }
}
