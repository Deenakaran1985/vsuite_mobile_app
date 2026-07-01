import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../models/vsuite_instance.dart';

class VmrfduProvider extends ChangeNotifier {
  final StorageService _store;
  final ApiService _api;

  static const hubUrl = 'http://14.139.184.39:8108';

  String? _token;
  Map<String, dynamic>? _user;
  List<VsuiteInstance> _instances = [];
  bool _loading = false;

  VmrfduProvider(this._store, this._api);

  String? get token      => _token;
  Map<String, dynamic>? get user => _user;
  List<VsuiteInstance> get instances => _instances;
  bool   get loading     => _loading;
  bool   get isLoggedIn  => _token != null;

  // ── Boot ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _token = await _store.loadVmrfduToken();
    _user  = await _store.loadVmrfduUser();
    notifyListeners();
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    _loading = true;
    notifyListeners();

    final result = await _api.mobileLogin(
      serverUrl: hubUrl,
      email: email,
      password: password,
    );

    _loading = false;

    if (result['success'] == true) {
      _token = result['token'] as String?;
      _user  = result['user']  as Map<String, dynamic>?;

      final raw = result['instances'];
      if (raw is List) {
        _instances = raw
            .whereType<Map<String, dynamic>>()
            .map((e) => VsuiteInstance.fromJson(e))
            .toList();
      }

      if (_token != null) await _store.saveVmrfduToken(_token!);
      if (_user  != null) await _store.saveVmrfduUser(_user!);
    }

    notifyListeners();
    return result;
  }

  // ── Fetch instances (refresh) ─────────────────────────────────────────────

  Future<void> refreshInstances() async {
    final list = await _api.fetchServerInstances(hubUrl);
    _instances = list
        .map((e) => VsuiteInstance.fromJson(e))
        .toList();
    notifyListeners();
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    if (_token != null) {
      await _api.mobileLogout(serverUrl: hubUrl, token: _token!);
    }
    _token     = null;
    _user      = null;
    _instances = [];
    await _store.deleteVmrfduToken();
    await _store.deleteVmrfduUser();
    notifyListeners();
  }
}
