import 'package:flutter/foundation.dart';
import '../models/vsuite_instance.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class InstanceProvider extends ChangeNotifier {
  final StorageService _store;
  final ApiService _api;

  List<VsuiteInstance> _instances = [];
  int _activeIndex = 0;
  final bool _loading = false;

  InstanceProvider(this._store, this._api);

  List<VsuiteInstance> get instances   => _instances;
  int                  get activeIndex => _activeIndex;
  bool                 get loading     => _loading;
  ApiService           get api         => _api;

  VsuiteInstance? get activeInstance =>
      _instances.isEmpty ? null : _instances[_activeIndex.clamp(0, _instances.length - 1)];

  // ── Boot ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _instances   = await _store.loadInstances();
    _activeIndex = await _store.loadActiveIndex();
    _activeIndex = _activeIndex.clamp(0, _instances.isEmpty ? 0 : _instances.length - 1);
    notifyListeners();
  }

  // ── Add / edit / delete ───────────────────────────────────────────────────

  Future<void> addInstance(VsuiteInstance inst, String password) async {
    _instances.add(inst);
    await _store.saveInstances(_instances);
    await _store.savePassword(inst.id, password);
    notifyListeners();
  }

  Future<void> updateInstance(VsuiteInstance inst, {String? newPassword}) async {
    final idx = _instances.indexWhere((i) => i.id == inst.id);
    if (idx == -1) return;
    _instances[idx] = inst;
    await _store.saveInstances(_instances);
    if (newPassword != null) await _store.savePassword(inst.id, newPassword);
    // Invalidate token so it re-authenticates with new details
    await _store.deleteToken(inst.id);
    notifyListeners();
  }

  Future<void> removeInstance(String instanceId) async {
    _instances.removeWhere((i) => i.id == instanceId);
    await _store.saveInstances(_instances);
    await _store.deletePassword(instanceId);
    await _store.deleteToken(instanceId);
    if (_activeIndex >= _instances.length) {
      _activeIndex = (_instances.length - 1).clamp(0, 999);
      await _store.saveActiveIndex(_activeIndex);
    }
    notifyListeners();
  }

  // ── Switch active ─────────────────────────────────────────────────────────

  Future<void> switchTo(int idx) async {
    _activeIndex = idx.clamp(0, _instances.length - 1);
    await _store.saveActiveIndex(_activeIndex);
    notifyListeners();
  }

  // ── Token acquisition ─────────────────────────────────────────────────────

  Future<String?> getToken(VsuiteInstance instance) async {
    final pwd = await _store.loadPassword(instance.id);
    return _api.getToken(instance, pwd ?? '');
  }

  Future<void> invalidateToken(VsuiteInstance instance) async {
    await _api.invalidateToken(instance);
  }

  /// Stores a direct-login Bearer token and role after successful instance login.
  Future<void> storeInstanceToken(String instanceId, String token, String role) async {
    await _store.saveToken(instanceId, token);
    await _store.saveRole(instanceId, role);
    notifyListeners();
  }

  /// Returns the stored role for the active instance (defaults to 'Staff').
  Future<String> getActiveRole() async {
    final inst = activeInstance;
    if (inst == null) return 'Staff';
    return await _store.loadRole(inst.id) ?? 'Staff';
  }

  // ── Auth check (does any instance exist?) ─────────────────────────────────

  bool get hasInstances => _instances.isNotEmpty;
}
