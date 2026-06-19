import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../models/vsuite_instance.dart';
import '../services/api_service.dart';

enum DocLoadState { idle, loading, loaded, error }

class InstanceDocState {
  final VsuiteInstance instance;
  DocLoadState state;
  String? errorMsg;
  List<DocumentModel> pending;
  List<DocumentModel> completed;

  InstanceDocState({
    required this.instance,
    this.state     = DocLoadState.idle,
    this.errorMsg,
    this.pending   = const [],
    this.completed = const [],
  });

  int get pendingCount   => pending.length;
  int get completedCount => completed.length;
  int get approvedCount  => completed.where((d) =>
      (d.approvalStatus ?? '').contains('Approved by Chairman')).length;
}

class DocumentProvider extends ChangeNotifier {
  final ApiService _api;

  final Map<String, InstanceDocState> _states = {};

  DocumentProvider(this._api);

  InstanceDocState? stateFor(VsuiteInstance inst) => _states[inst.id];

  // ── Load data for one instance ────────────────────────────────────────────

  Future<void> loadForInstance(VsuiteInstance instance, String token) async {
    _states[instance.id] = InstanceDocState(instance: instance, state: DocLoadState.loading);
    notifyListeners();

    try {
      final pending   = await _api.getPendingDocuments(instance, token);
      final completed = await _api.getCompletedDocuments(instance, token);

      _states[instance.id] = InstanceDocState(
        instance:  instance,
        state:     DocLoadState.loaded,
        pending:   pending,
        completed: completed,
      );
    } catch (e) {
      _states[instance.id] = InstanceDocState(
        instance: instance,
        state:    DocLoadState.error,
        errorMsg: e.toString(),
      );
    }
    notifyListeners();
  }

  // ── Document detail ───────────────────────────────────────────────────────

  Future<DocumentModel?> fetchDocument(VsuiteInstance instance, String token, int id) async {
    return _api.getDocument(instance, token, id);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> approve(VsuiteInstance instance, String token, int docId, Map<String, dynamic> payload) =>
      _api.approve(instance, token, docId, payload);

  Future<Map<String, dynamic>> reject(VsuiteInstance instance, String token, int docId, String message) =>
      _api.reject(instance, token, docId, message);

  Future<Map<String, dynamic>> hold(VsuiteInstance instance, String token, int docId, String message) =>
      _api.hold(instance, token, docId, message);

  Future<Map<String, dynamic>> comment(VsuiteInstance instance, String token, int docId, String message) =>
      _api.comment(instance, token, docId, message);
}
