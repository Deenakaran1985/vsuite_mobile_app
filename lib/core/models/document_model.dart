class DocumentModel {
  final int id;
  final String? docId;
  final String? title;
  final String? subject;
  final String? description;
  final String? from;
  final String? to;
  final String? forwardedTo;
  final String? status;
  final String? approvalStatus;
  final String? priority;
  final String? isPaymentInvolved;
  final double? amount;
  final double? recommendedAmount;
  final double? sanctionedAmount;
  final List<String> approvalSequence;
  final int currentSequenceIndex;
  final String? currentApprover;
  final int approvalProgressPct;
  final bool isFullyApproved;
  final String? createdBy;
  final String? createdByDept;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ApprovalLogEntry> approvalLog;

  const DocumentModel({
    required this.id,
    this.docId,
    this.title,
    this.subject,
    this.description,
    this.from,
    this.to,
    this.forwardedTo,
    this.status,
    this.approvalStatus,
    this.priority,
    this.isPaymentInvolved,
    this.amount,
    this.recommendedAmount,
    this.sanctionedAmount,
    this.approvalSequence = const [],
    this.currentSequenceIndex = 0,
    this.currentApprover,
    this.approvalProgressPct = 0,
    this.isFullyApproved = false,
    this.createdBy,
    this.createdByDept,
    this.createdAt,
    this.updatedAt,
    this.approvalLog = const [],
  });

  static double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());
  static int    _i(dynamic v, [int fallback = 0]) => int.tryParse(v?.toString() ?? '') ?? fallback;

  factory DocumentModel.fromJson(Map<String, dynamic> j) => DocumentModel(
    id:                    _i(j['id']),
    docId:                 j['doc_id']?.toString(),
    title:                 j['title']?.toString(),
    subject:               j['subject']?.toString(),
    description:           j['description']?.toString(),
    from:                  j['from']?.toString(),
    to:                    j['to']?.toString(),
    forwardedTo:           j['forwarded_to']?.toString(),
    status:                j['status']?.toString(),
    approvalStatus:        j['approval_status']?.toString(),
    priority:              j['priority']?.toString(),
    isPaymentInvolved:     j['is_payment_involved']?.toString(),
    amount:                _d(j['amount']),
    recommendedAmount:     _d(j['recommended_amount']),
    sanctionedAmount:      _d(j['sanctioned_amount']),
    approvalSequence:      List<String>.from(j['approval_sequence'] ?? []),
    currentSequenceIndex:  _i(j['current_sequence_index']),
    currentApprover:       j['current_approver']?.toString(),
    approvalProgressPct:   _i(j['approval_progress_pct']),
    isFullyApproved:       j['is_fully_approved'] == true || j['is_fully_approved'] == 1,
    createdBy:             j['created_by']?.toString(),
    createdByDept:         j['created_by_dept']?.toString(),
    createdAt:             j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
    updatedAt:             j['updated_at'] != null ? DateTime.tryParse(j['updated_at'].toString()) : null,
    approvalLog:           (j['approval_log'] as List<dynamic>?)
                              ?.map((e) => ApprovalLogEntry.fromJson(e as Map<String, dynamic>))
                              .toList() ?? [],
  );

  int get daysPending => createdAt != null ? DateTime.now().difference(createdAt!).inDays : 0;

  bool get isAtChairmanStage {
    const chairmanDepts = ['Chairman', 'Chancellor', 'Chancellor Office'];
    return chairmanDepts.contains(currentApprover);
  }
}

class ApprovalLogEntry {
  final String? action;
  final String? message;
  final String? byName;
  final String? byDept;
  final DateTime? createdAt;

  const ApprovalLogEntry({this.action, this.message, this.byName, this.byDept, this.createdAt});

  factory ApprovalLogEntry.fromJson(Map<String, dynamic> j) => ApprovalLogEntry(
    action:    j['action'] as String?,
    message:   j['message'] as String?,
    byName:    j['by_name'] as String?,
    byDept:    j['by_dept'] as String?,
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
  );
}
