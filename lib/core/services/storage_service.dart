import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vsuite_instance.dart';

class StorageService {
  static const _storage  = FlutterSecureStorage();
  static const _keyInstances = 'vsuite_instances';
  static const _keyActiveIdx = 'vsuite_active_idx';

  // ── Instances ─────────────────────────────────────────────────────────────

  Future<List<VsuiteInstance>> loadInstances() async {
    final raw = await _storage.read(key: _keyInstances);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => VsuiteInstance.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveInstances(List<VsuiteInstance> instances) async {
    final json = jsonEncode(instances.map((i) => i.toJson()).toList());
    await _storage.write(key: _keyInstances, value: json);
  }

  // ── Password per instance ─────────────────────────────────────────────────

  Future<void> savePassword(String instanceId, String password) async {
    await _storage.write(key: 'pwd_$instanceId', value: password);
  }

  Future<String?> loadPassword(String instanceId) async {
    return _storage.read(key: 'pwd_$instanceId');
  }

  Future<void> deletePassword(String instanceId) async {
    await _storage.delete(key: 'pwd_$instanceId');
  }

  // ── Bearer token per instance ─────────────────────────────────────────────

  Future<void> saveToken(String instanceId, String token) async {
    await _storage.write(key: 'tok_$instanceId', value: token);
  }

  Future<String?> loadToken(String instanceId) async {
    return _storage.read(key: 'tok_$instanceId');
  }

  Future<void> deleteToken(String instanceId) async {
    await _storage.delete(key: 'tok_$instanceId');
  }

  // ── Active instance index ─────────────────────────────────────────────────

  Future<int> loadActiveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyActiveIdx) ?? 0;
  }

  Future<void> saveActiveIndex(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyActiveIdx, idx);
  }

  // ── Wipe everything (logout) ──────────────────────────────────────────────

  Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
