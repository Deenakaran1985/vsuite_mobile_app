import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../models/vsuite_instance.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _store;
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 20)));

  ApiService(this._store);

  // ── Server discovery: fetch configured instances from vmrfdu-vsuite ──────

  Future<List<Map<String, dynamic>>> fetchServerInstances(String serverUrl) async {
    try {
      final res = await _dio.get(
        '${_trimUrl(serverUrl)}/api/v1/instances',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['instances'] as List);
      }
    } on DioException catch (e) {
      _log('fetchServerInstances', e);
    }
    return [];
  }

  // ── Cross-auth: get/cache a Bearer token for an instance ─────────────────

  Future<String?> getToken(VsuiteInstance instance, String password) async {
    // Return cached token first
    final cached = await _store.loadToken(instance.id);
    if (cached != null) return cached;

    // Request fresh token via cross-auth
    try {
      final res = await _dio.post(
        '${_trimUrl(instance.url)}/api/v1/cross-auth/chairman',
        data: {'email': instance.email, 'source_app': 'VSuite-Mobile'},
      );
      if (res.data['success'] == true) {
        final token = res.data['data']['token'] as String;
        await _store.saveToken(instance.id, token);
        return token;
      }
    } on DioException catch (e) {
      _log('cross-auth failed', e);
    }
    return null;
  }

  Future<void> invalidateToken(VsuiteInstance instance) async {
    await _store.deleteToken(instance.id);
  }

  // ── Device / Push-notification tokens ─────────────────────────────────────

  Future<void> registerDeviceToken({
    required String serverUrl,
    required String bearerToken,
    required String fcmToken,
    String platform = 'android',
  }) async {
    try {
      await _dio.post(
        '${_trimUrl(serverUrl)}/api/v1/device-token',
        data: {'fcm_token': fcmToken, 'platform': platform},
        options: Options(headers: {'Authorization': 'Bearer $bearerToken', 'Accept': 'application/json'}),
      );
    } on DioException catch (e) {
      _log('registerDeviceToken', e);
    }
  }

  Future<void> removeDeviceToken({
    required String serverUrl,
    required String bearerToken,
    required String fcmToken,
  }) async {
    try {
      await _dio.delete(
        '${_trimUrl(serverUrl)}/api/v1/device-token',
        data: {'fcm_token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $bearerToken', 'Accept': 'application/json'}),
      );
    } on DioException catch (e) {
      _log('removeDeviceToken', e);
    }
  }

  // ── Direct instance login (v-suite) ───────────────────────────────────────

  Future<Map<String, dynamic>> instanceLogin({
    required String instanceUrl,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '${_trimUrl(instanceUrl)}/api/v1/auth/login',
        data: {'email': email, 'password': password},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _log('instanceLogin', e);
      final msg = e.response?.data?['message'] as String? ?? 'Login failed';
      return {'success': false, 'message': msg};
    }
  }

  // ── Mobile auth login (vmrfdu-vsuite hub) ─────────────────────────────────

  Future<Map<String, dynamic>> mobileLogin({
    required String serverUrl,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '${_trimUrl(serverUrl)}/api/v1/auth/login',
        data: {'email': email, 'password': password},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _log('mobileLogin', e);
      final msg = e.response?.data?['message'] as String? ?? 'Login failed';
      return {'success': false, 'message': msg};
    }
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  Future<List<DocumentModel>> getPendingDocuments(VsuiteInstance instance, String token) async {
    final data = await _get(instance, token, '/api/v1/documents/pending');
    if (data == null) return [];
    final list = data['data'];
    if (list is! List) return [];
    return list.map((e) => DocumentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DocumentModel>> getCompletedDocuments(VsuiteInstance instance, String token, {int perPage = 30}) async {
    final data = await _get(instance, token, '/api/v1/documents/completed', params: {'per_page': perPage});
    if (data == null) return [];
    final list = data['data'];
    if (list is! List) return [];
    return list.map((e) => DocumentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DocumentModel?> getDocument(VsuiteInstance instance, String token, int id) async {
    final data = await _get(instance, token, '/api/v1/documents/$id');
    if (data == null || data['data'] == null) return null;
    return DocumentModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> approve(VsuiteInstance instance, String token, int docId, Map<String, dynamic> payload) =>
      _post(instance, token, '/api/v1/documents/$docId/chairman-approve', payload);

  Future<Map<String, dynamic>> reject(VsuiteInstance instance, String token, int docId, String message) =>
      _post(instance, token, '/api/v1/documents/$docId/reject', {'message': message});

  Future<Map<String, dynamic>> hold(VsuiteInstance instance, String token, int docId, String message) =>
      _post(instance, token, '/api/v1/documents/$docId/hold', {'message': message});

  Future<Map<String, dynamic>> comment(VsuiteInstance instance, String token, int docId, String message) =>
      _post(instance, token, '/api/v1/documents/$docId/comment', {'message': message});

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _get(VsuiteInstance instance, String token, String path, {Map<String, dynamic>? params}) async {
    try {
      final res = await _dio.get(
        '${_trimUrl(instance.url)}$path',
        queryParameters: params,
        options: Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}),
      );
      return res.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      _log('GET $path', e);
      return null;
    }
  }

  Future<Map<String, dynamic>> _post(VsuiteInstance instance, String token, String path, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post(
        '${_trimUrl(instance.url)}$path',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}),
      );
      final d = res.data as Map<String, dynamic>;
      return {'success': d['success'] ?? false, 'message': d['message'] ?? 'Done'};
    } on DioException catch (e) {
      _log('POST $path', e);
      final msg = e.response?.data?['message'] as String? ?? e.message ?? 'Network error';
      return {'success': false, 'message': msg};
    }
  }

  String _trimUrl(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  void _log(String tag, Object e) => debugPrint('[ApiService] $tag: $e');
}
