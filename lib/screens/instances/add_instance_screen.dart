import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/vsuite_instance.dart';
import '../../core/providers/instance_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';

class AddInstanceScreen extends StatefulWidget {
  final VsuiteInstance? editing; // null = new
  const AddInstanceScreen({super.key, this.editing});

  @override
  State<AddInstanceScreen> createState() => _AddInstanceScreenState();
}

class _AddInstanceScreenState extends State<AddInstanceScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _labelCtl = TextEditingController();
  final _urlCtl   = TextEditingController();
  final _emailCtl = TextEditingController();
  final _pwdCtl   = TextEditingController();

  bool _obscure  = true;
  bool _testing  = false;
  bool _saving   = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _labelCtl.text = widget.editing!.label;
      _urlCtl.text   = widget.editing!.url;
      _emailCtl.text = widget.editing!.email;
    }
  }

  @override
  void dispose() {
    _labelCtl.dispose(); _urlCtl.dispose(); _emailCtl.dispose(); _pwdCtl.dispose();
    super.dispose();
  }

  Future<void> _browseFromServer() async {
    final serverCtl = TextEditingController(text: 'http://14.139.184.39:8108');
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _BrowseDialog(serverCtl: serverCtl),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _labelCtl.text = picked['label'] as String? ?? '';
      _urlCtl.text   = picked['url']   as String? ?? '';
    });
    Fluttertoast.showToast(
      msg: 'Instance loaded — enter your email and password to connect.',
      backgroundColor: AppColors.primary,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _testing = true);

    final inst = _buildInstance();
    final svc  = ApiService(StorageService());
    final token = await svc.getToken(inst, _pwdCtl.text.trim());

    setState(() => _testing = false);

    if (!mounted) return;
    if (token != null) {
      Fluttertoast.showToast(msg: 'Connection successful!', backgroundColor: AppColors.success, textColor: Colors.white);
    } else {
      Fluttertoast.showToast(msg: 'Connection failed — check URL and email.', backgroundColor: AppColors.danger, textColor: Colors.white);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final inst     = _buildInstance();
    final provider = context.read<InstanceProvider>();

    if (widget.editing == null) {
      await provider.addInstance(inst, _pwdCtl.text.trim());
    } else {
      await provider.updateInstance(
        inst,
        newPassword: _pwdCtl.text.trim().isEmpty ? null : _pwdCtl.text.trim(),
      );
    }

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  VsuiteInstance _buildInstance() => VsuiteInstance(
    id:    widget.editing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    label: _labelCtl.text.trim(),
    url:   _urlCtl.text.trim(),
    email: _emailCtl.text.trim(),
  );

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
                const SizedBox(height: 20),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/images/logo1.jpg', width: 72, height: 72, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Edit Instance' : 'Add VSuite Instance',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                Text(
                  isEdit ? 'Update connection details' : 'Connect your VSuite account',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
                ),
                const SizedBox(height: 32),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isEdit) ...[
                            OutlinedButton.icon(
                              onPressed: _browseFromServer,
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('Browse from Server'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Row(children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('or enter manually', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ),
                              Expanded(child: Divider()),
                            ]),
                            const SizedBox(height: 10),
                          ],
                          _field(_labelCtl, 'Instance Name', 'e.g. VIMS-V-Suite', Icons.label_outline),
                          const SizedBox(height: 14),
                          _field(_urlCtl, 'Server URL', 'http://14.139.184.39:8101', Icons.link,
                              keyboardType: TextInputType.url),
                          const SizedBox(height: 14),
                          _field(_emailCtl, 'Email', 'you@example.com', Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller:  _pwdCtl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText:   isEdit ? 'Password (leave blank to keep)' : 'Password',
                              hintText:    '••••••••',
                              prefixIcon:  const Icon(Icons.lock_outline),
                              suffixIcon:  IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (!isEdit && (v == null || v.isEmpty)) return 'Password is required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: _testing ? null : _testConnection,
                            icon: _testing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.wifi_tethering),
                            label: Text(_testing ? 'Testing…' : 'Test Connection'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(isEdit ? 'Save Changes' : 'Add & Connect'),
                          ),
                          if (isEdit) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
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

  Widget _field(TextEditingController ctl, String label, String hint, IconData icon,
      {TextInputType? keyboardType}) =>
    TextFormField(
      controller:   ctl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        prefixIcon: Icon(icon),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null,
    );
}

// ── Browse-from-server dialog ─────────────────────────────────────────────

class _BrowseDialog extends StatefulWidget {
  final TextEditingController serverCtl;
  const _BrowseDialog({required this.serverCtl});

  @override
  State<_BrowseDialog> createState() => _BrowseDialogState();
}

class _BrowseDialogState extends State<_BrowseDialog> {
  List<Map<String, dynamic>> _instances = [];
  bool   _loading = false;
  String _error   = '';

  Future<void> _fetch() async {
    final url = widget.serverCtl.text.trim();
    if (url.isEmpty) return;
    setState(() { _loading = true; _error = ''; _instances = []; });
    final results = await ApiService(StorageService()).fetchServerInstances(url);
    if (!mounted) return;
    if (results.isEmpty) {
      setState(() { _loading = false; _error = 'No instances found or server unreachable.'; });
    } else {
      setState(() { _loading = false; _instances = results; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Browse Instances'),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter the main VMRFDU-VSuite server URL:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: widget.serverCtl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'http://14.139.184.39:8108',
              prefixIcon: Icon(Icons.dns_outlined),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _loading ? null : _fetch,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: Text(_loading ? 'Fetching…' : 'Fetch Instances'),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          if (_instances.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const Text('Select an instance:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            ..._instances.map((inst) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dns, color: AppColors.primary),
              title: Text(inst['label'] as String? ?? ''),
              subtitle: Text(inst['url'] as String? ?? '', style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(context, inst),
            )),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
    ],
  );
}
