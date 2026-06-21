import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  static const _keyPin     = 'vsuite_pin_hash';
  static const _keyEnabled = 'vsuite_pin_enabled';
  final _store = const FlutterSecureStorage();

  String _hash(String pin) =>
      sha256.convert(utf8.encode('vsuite_salt_$pin')).toString();

  Future<bool> hasPin() async {
    final v = await _store.read(key: _keyEnabled);
    return v == 'true';
  }

  Future<void> setPin(String pin) async {
    await _store.write(key: _keyPin,     value: _hash(pin));
    await _store.write(key: _keyEnabled, value: 'true');
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _store.read(key: _keyPin);
    return stored != null && stored == _hash(pin);
  }

  Future<void> clearPin() async {
    await _store.delete(key: _keyPin);
    await _store.write(key: _keyEnabled, value: 'false');
  }
}
