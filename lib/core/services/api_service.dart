import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../models/vsuite_instance.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _store;
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 20)));

  ApiService(this._store);

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
