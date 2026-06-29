import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/document_model.dart';
import '../../core/models/vsuite_instance.dart';
import '../../core/providers/document_provider.dart';
import '../../core/providers/instance_provider.dart';
import '../../core/services/biometric_service.dart';

class DocumentDetailScreen extends StatefulWidget {
  final DocumentModel  doc;
  final VsuiteInstance instance;
  const DocumentDetailScreen({super.key, required this.doc, required this.instance});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  DocumentModel? _doc;
  bool   _loadingDetail = false;
  bool   _acting        = false;
  String _role          = 'Staff';

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
    _fetchDetail();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await context.read<InstanceProvider>().getRole(widget.instance);
    if (mounted) setState(() => _role = role);
  }

  Future<void> _fetchDetail() async {
    setState(() => _loadingDetail = true);
    final inst  = context.read<InstanceProvider>();
    final docs  = context.read<DocumentProvider>();
    final token = await inst.getToken(widget.instance);
    if (token != null) {
      final full = await docs.fetchDocument(widget.instance, token, widget.doc.id);
      if (full != null && mounted) setState(() => _doc = full);
    }
    if (mounted) setState(() => _loadingDetail = false);
  }

  Future<String?> _getToken() async =>
      context.read<InstanceProvider>().getToken(widget.instance);

  Future<void> _act(
      Future<Map<String, dynamic>> Function(String token, Map<String, dynamic> extra) action) async {
    // Biometric / PIN verification before any document action
    final bio = BiometricService();
    var bioVerified = false;
    final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'unknown';

    if (await bio.isAvailable()) {
      bioVerified = await bio.authenticate(
          reason: 'Verify your identity to perform this action');
      if (!bioVerified) {
        _toast('Authentication cancelled. No action taken.', isError: true);
        return;
      }
    }

    final extra = {
      'biometric_verified': bioVerified,
      'platform': platform,
      'device_info': Platform.operatingSystemVersion,
    };

    setState(() => _acting = true);
    final token = await _getToken();
    if (token == null) {
      _toast('Session expired. Please log in again.', isError: true);
      setState(() => _acting = false);
      return;
    }
    final result = await action(token, extra);
    setState(() => _acting = false);
    _toast(result['message'] ?? 'Done', isError: result['success'] != true);
    if (result['success'] == true) await _fetchDetail();
  }

  void _toast(String msg, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: msg,
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  bool get _isChairman => _role == 'Chairman';
  bool get _isStaff    => _role == 'Staff';

  // ── Action sheets ─────────────────────────────────────────────────────────

  void _showChairmanApproveSheet() {
    final msgCtl   = TextEditingController();
    final recCtl   = TextEditingController(text: _doc?.recommendedAmount?.toString() ?? '');
    final sanCtl   = TextEditingController(text: _doc?.sanctionedAmount?.toString() ?? '');
    String? finHead;
    final isPayment = (_doc?.isPaymentInvolved ?? '') == 'Y';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: StatefulBuilder(
          builder: (ctx, setSt) => SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Chairman Approve', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const Divider(height: 20),
              if (isPayment) ...[
                Row(children: [
                  Expanded(child: TextField(controller: recCtl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Recommended (₹)', isDense: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: sanCtl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sanctioned (₹)', isDense: true))),
                ]),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Finance Head (optional)', isDense: true),
                  initialValue: finHead,
                  items: const [
                    DropdownMenuItem(value: null,                          child: Text('— System decides —')),
                    DropdownMenuItem(value: 'Finance Head Salem',         child: Text('Finance Head Salem')),
                    DropdownMenuItem(value: 'Finance Head Chennai',       child: Text('Finance Head Chennai')),
                    DropdownMenuItem(value: 'Finance Head Karaikal',      child: Text('Finance Head Karaikal')),
                    DropdownMenuItem(value: 'Finance Head Pondy',         child: Text('Finance Head Pondy')),
                  ],
                  onChanged: (v) => setSt(() => finHead = v),
                ),
                const SizedBox(height: 14),
              ],
              TextField(controller: msgCtl, decoration: const InputDecoration(labelText: 'Remarks (optional)', isDense: true), maxLines: 2),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  final payload = <String, dynamic>{};
                  if (msgCtl.text.isNotEmpty) payload['message'] = msgCtl.text;
                  if (finHead != null) payload['finance_head'] = finHead;
                  if (recCtl.text.isNotEmpty) payload['recommended_amount'] = double.tryParse(recCtl.text);
                  if (sanCtl.text.isNotEmpty) payload['sanctioned_amount']  = double.tryParse(sanCtl.text);
                  _act((token, extra) => context.read<DocumentProvider>().approve(
                        widget.instance, token, widget.doc.id, {...payload, ...extra}));
                },
                icon: const Icon(Icons.check),
                label: const Text('Confirm Approve'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }

  void _showGeneralApproveSheet() {
    final msgCtl = TextEditingController();
    final recCtl = TextEditingController(text: _doc?.recommendedAmount?.toString() ?? '');
    final sanCtl = TextEditingController(text: _doc?.sanctionedAmount?.toString() ?? '');
    final isPayment = (_doc?.isPaymentInvolved ?? '') == 'Y';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Approve Document', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Divider(height: 20),
            if (isPayment) ...[
              Row(children: [
                Expanded(child: TextField(controller: recCtl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Recommended (₹)', isDense: true))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: sanCtl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sanctioned (₹)', isDense: true))),
              ]),
              const SizedBox(height: 14),
            ],
            TextField(controller: msgCtl, decoration: const InputDecoration(labelText: 'Remarks (optional)', isDense: true), maxLines: 2),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                final payload = <String, dynamic>{};
                if (msgCtl.text.isNotEmpty) payload['message'] = msgCtl.text;
                if (recCtl.text.isNotEmpty) payload['recommended_amount'] = double.tryParse(recCtl.text);
                if (sanCtl.text.isNotEmpty) payload['sanctioned_amount']  = double.tryParse(sanCtl.text);
                _act((token, extra) => context.read<DocumentProvider>().generalApprove(
                      widget.instance, token, widget.doc.id, {...payload, ...extra}));
              },
              icon: const Icon(Icons.check),
              label: const Text('Confirm Approve'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  void _showForwardSheet() {
    final deptCtl = TextEditingController();
    final msgCtl  = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Forward Document', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Divider(height: 20),
          TextField(
            controller: deptCtl,
            decoration: const InputDecoration(labelText: 'Forward to (Department)', isDense: true, prefixIcon: Icon(Icons.send)),
          ),
          const SizedBox(height: 14),
          TextField(controller: msgCtl, maxLines: 2, decoration: const InputDecoration(hintText: 'Message (optional)', isDense: true)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
            onPressed: () {
              if (deptCtl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _act((token, extra) => context.read<DocumentProvider>().forward(
                    widget.instance, token, widget.doc.id, deptCtl.text.trim(), msgCtl.text.trim(), extra: extra));
            },
            icon: const Icon(Icons.send),
            label: const Text('Forward'),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _showRejectSheet()  => _showReasonSheet('Reject Document',       AppColors.danger,  'Rejection reason (required)',
      (token, msg, extra) => context.read<DocumentProvider>().reject(widget.instance, token, widget.doc.id, msg, extra: extra), required: true);

  void _showHoldSheet()    => _showReasonSheet('Put on Hold',           AppColors.warning, 'Hold reason (required)',
      (token, msg, extra) => context.read<DocumentProvider>().hold(widget.instance, token, widget.doc.id, msg, extra: extra), required: true);

  void _showNotedSheet()   => _showReasonSheet('Mark as Noted',         AppColors.accent,  'Remarks (optional)',
      (token, msg, extra) => context.read<DocumentProvider>().noted(widget.instance, token, widget.doc.id, msg, extra: extra));

  void _showDiscussSheet() => _showReasonSheet('Call for Discussion',   AppColors.info,    'Discussion reason (required)',
      (token, msg, extra) => context.read<DocumentProvider>().discuss(widget.instance, token, widget.doc.id, msg, extra: extra), required: true);

  void _showCommentSheet() => _showReasonSheet('Add Comment',           AppColors.accent,  'Write a comment…',
      (token, msg, extra) => context.read<DocumentProvider>().comment(widget.instance, token, widget.doc.id, msg, extra: extra));

  void _showCompleteSheet() => _showReasonSheet('Complete Process',     AppColors.success, 'Completion remarks (optional)',
      (token, msg, extra) => context.read<DocumentProvider>().complete(widget.instance, token, widget.doc.id, msg, extra: extra));

  void _showReasonSheet(String title, Color color, String hint,
      Future<Map<String, dynamic>> Function(String, String, Map<String, dynamic>) action, {bool required = false}) {
    final ctl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Divider(height: 20),
          TextField(controller: ctl, maxLines: 3, decoration: InputDecoration(hintText: hint)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () {
              if (required && ctl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _act((token, extra) => action(token, ctl.text.trim(), extra));
            },
            child: Text(title),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final doc = _doc ?? widget.doc;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
          ),
        ),
        title: Text(doc.docId ?? 'Document', style: const TextStyle(fontSize: 15)),
        actions: [
          if (_role.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_role, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          if (_loadingDetail)
            const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetail),
        ],
      ),
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Header card ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _pill(doc.docId ?? '—'),
                  const SizedBox(width: 8),
                  _statusPill(doc.status),
                  const Spacer(),
                  _priorityPill(doc.priority),
                ]),
                const SizedBox(height: 10),
                Text(doc.title ?? 'Untitled', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('From: ${doc.from ?? '—'}  ·  By: ${doc.createdBy ?? '—'}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                if (doc.createdAt != null)
                  Text(DateFormat('dd MMM yyyy').format(doc.createdAt!), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 14),
            // ── Progress ─────────────────────────────────────────────────
            _card('Approval Progress', [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${doc.approvalProgressPct}% Complete', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Step ${doc.currentSequenceIndex}/${doc.approvalSequence.length}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: doc.approvalProgressPct / 100,
                backgroundColor: AppColors.border,
                color: AppColors.accent,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 12),
              ...doc.approvalSequence.asMap().entries.map((e) {
                final idx  = e.key;
                final step = e.value;
                final done = idx < doc.currentSequenceIndex;
                final curr = idx == doc.currentSequenceIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: done ? AppColors.success : curr ? AppColors.accent : AppColors.border,
                      child: done
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : curr
                              ? const Icon(Icons.access_time, color: Colors.white, size: 13)
                              : Text('${idx + 1}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(step, style: TextStyle(fontWeight: curr ? FontWeight.w700 : FontWeight.normal,
                        color: done ? AppColors.success : curr ? AppColors.accent : AppColors.textMuted))),
                    if (curr) const Text('← Current', style: TextStyle(fontSize: 10, color: AppColors.accent)),
                  ]),
                );
              }),
            ]),
            const SizedBox(height: 14),
            // ── Subject ──────────────────────────────────────────────────
            if (doc.subject != null) ...[
              _card('Subject', [Text(doc.subject!, style: const TextStyle(fontSize: 14))]),
              const SizedBox(height: 14),
            ],
            // ── Financial ────────────────────────────────────────────────
            if (doc.isPaymentInvolved == 'Y')
              _card('Financial Details', [
                Row(children: [
                  Expanded(child: _finStat('Requested', doc.amount)),
                  Expanded(child: _finStat('Recommended', doc.recommendedAmount, color: AppColors.info)),
                  Expanded(child: _finStat('Sanctioned', doc.sanctionedAmount, color: AppColors.success)),
                ]),
              ]),
            if (doc.isPaymentInvolved == 'Y') const SizedBox(height: 14),
            // ── Approval log ─────────────────────────────────────────────
            if (doc.approvalLog.isNotEmpty)
              _card('Approval History', [
                ...doc.approvalLog.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 5, right: 10),
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.action ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (e.message != null && e.message!.isNotEmpty)
                        Text('"${e.message}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                      Text(
                        '${e.byName ?? '—'} · ${e.byDept ?? ''}  ${e.createdAt != null ? DateFormat('dd MMM yy, hh:mm a').format(e.createdAt!.toLocal()) : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ])),
                  ]),
                )),
              ]),
            const SizedBox(height: 110),
          ]),
        ),
        // ── Floating action bar — shown when document is actionable ──────
        if (doc.isActionable && !['Completed', 'Closed', 'Rejected'].contains(doc.status))
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, -4))],
              ),
              child: _acting
                  ? const Center(child: CircularProgressIndicator())
                  : _buildActionBar(),
            ),
          ),
        // ── Comment FAB (always visible unless doc closed) ───────────────
        if (!['Completed', 'Closed'].contains(doc.status))
          Positioned(
            bottom: (doc.isActionable && !['Completed', 'Closed', 'Rejected'].contains(doc.status)) ? 92 : 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _showCommentSheet,
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.comment_outlined, color: Colors.white),
            ),
          ),
      ]),
    );
  }

  Widget _buildActionBar() {
    if (_isChairman) {
      return Row(children: [
        Expanded(child: _actionBtn('Approve', AppColors.success, Icons.check, _showChairmanApproveSheet)),
        const SizedBox(width: 8),
        Expanded(child: _actionBtn('Hold', AppColors.warning, Icons.pause, _showHoldSheet)),
        const SizedBox(width: 8),
        Expanded(child: _actionBtn('Reject', AppColors.danger, Icons.close, _showRejectSheet)),
      ]);
    }

    if (_isStaff) {
      // Staff only gets Complete if the doc has gone through the full sequence
      final doc = _doc ?? widget.doc;
      final isCreatorAndDone = doc.isFullyApproved || doc.approvalProgressPct == 100;
      if (isCreatorAndDone) {
        return Row(children: [
          Expanded(child: _actionBtn('Complete', AppColors.success, Icons.flag, _showCompleteSheet)),
        ]);
      }
      return const SizedBox.shrink();
    }

    // HOD, Admin, SuperAdmin — full action bar
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: _actionBtn('Approve', AppColors.success,  Icons.check,       _showGeneralApproveSheet)),
        const SizedBox(width: 8),
        Expanded(child: _actionBtn('Hold',    AppColors.warning,  Icons.pause,       _showHoldSheet)),
        const SizedBox(width: 8),
        Expanded(child: _actionBtn('Reject',  AppColors.danger,   Icons.close,       _showRejectSheet)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _actionBtn('Noted',   AppColors.accent,   Icons.done_all,    _showNotedSheet)),
        const SizedBox(width: 8),
        Expanded(child: _actionBtn('Discuss', AppColors.info,     Icons.forum,       _showDiscussSheet)),
        const SizedBox(width: 8),
        Expanded(child: _actionBtn('Forward', const Color(0xFF6A1B9A), Icons.send,   _showForwardSheet)),
      ]),
    ]);
  }

  Widget _card(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          letterSpacing: 0.5, color: AppColors.accent)),
      const SizedBox(height: 12),
      ...children,
    ]),
  );

  Widget _finStat(String label, double? value, {Color color = AppColors.textDark}) => Column(children: [
    Text(value != null ? '₹${NumberFormat('#,##,###').format(value)}' : '—',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
  ]);

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Widget _statusPill(String? status) {
    Color bg;
    if ((status ?? '').contains('Reject')) { bg = AppColors.danger.withValues(alpha: 0.3); }
    else if ((status ?? '').contains('Complet')) { bg = AppColors.success.withValues(alpha: 0.3); }
    else if ((status ?? '').contains('Hold')) { bg = AppColors.warning.withValues(alpha: 0.3); }
    else { bg = Colors.white.withValues(alpha: 0.15); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status ?? '—', style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  Widget _priorityPill(String? p) {
    Color bg;
    switch ((p ?? '').toLowerCase()) {
      case 'high': case 'urgent': bg = AppColors.danger; break;
      case 'medium': case 'normal': bg = AppColors.warning; break;
      default: bg = AppColors.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(p ?? 'Normal', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback onTap) =>
    ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
}
