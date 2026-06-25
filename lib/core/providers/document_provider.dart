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
  List<DocumentModel> myDocuments;

  InstanceDocState({
    required this.instance,
    this.state       = DocLoadState.idle,
    this.errorMsg,
    this.pending     = const [],
    this.completed   = const [],
    this.myDocuments = const [],
  });

  int get pendingCount   => pending.length;
  int get completedCount => completed.length;
  int get approvedCount  => completed.where((d) =>
      (d.approvalStatus ?? '').toLowerCase().contains('approved')).length;
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
      final results = await Future.wait([
        _api.getPendingDocuments(instance, token),
        _api.getCompletedDocuments(instance, token),
        _api.getMyDocuments(instance, token),
      ]);

      _states[instance.id] = InstanceDocState(
        instance:    instance,
        state:       DocLoadState.loaded,
        pending:     results[0],
        completed:   results[1],
        myDocuments: results[2],
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

  Future<Map<String, dynamic>> generalApprove(VsuiteInstance instance, String token, int docId, Map<String, dynamic> payload) =>
      _api.generalApprove(instance, token, docId, payload);

  Future<Map<String, dynamic>> reject(VsuiteInstance instance, String token, int docId, String message) =>
      _api.reject(instance, token, docId, message);

  Future<Map<String, dynamic>> hold(VsuiteInstance instance, String token, int docId, String message) =>
      _api.hold(instance, token, docId, message);

  Future<Map<String, dynamic>> comment(VsuiteInstance instance, String token, int docId, String message) =>
      _api.comment(instance, token, docId, message);

  Future<Map<String, dynamic>> noted(VsuiteInstance instance, String token, int docId, String message) =>
      _api.noted(instance, token, docId, message);

  Future<Map<String, dynamic>> discuss(VsuiteInstance instance, String token, int docId, String message) =>
      _api.discuss(instance, token, docId, message);

  Future<Map<String, dynamic>> forward(VsuiteInstance instance, String token, int docId, String forwardTo, String message) =>
      _api.forward(instance, token, docId, forwardTo, message);

  Future<Map<String, dynamic>> complete(VsuiteInstance instance, String token, int docId, String message) =>
      _api.complete(instance, token, docId, message);
}
