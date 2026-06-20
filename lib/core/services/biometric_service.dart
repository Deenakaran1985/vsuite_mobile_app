import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _prefKey = 'biometric_enabled';
  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      return (await _auth.canCheckBiometrics) || (await _auth.isDeviceSupported());
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> availableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // Returns a human-readable label for the strongest available biometric.
  Future<String> biometricLabel() async {
    final types = await availableTypes();
    if (types.contains(BiometricType.face))        return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (types.contains(BiometricType.strong))      return 'Biometrics';
    return 'Biometrics';
  }

  Future<bool> authenticate({String? reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason ?? 'Verify your identity to access VSuite',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN as fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }
}
