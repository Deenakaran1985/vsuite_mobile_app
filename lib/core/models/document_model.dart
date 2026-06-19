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

  factory DocumentModel.fromJson(Map<String, dynamic> j) => DocumentModel(
    id:                    j['id'] as int,
    docId:                 j['doc_id'] as String?,
    title:                 j['title'] as String?,
    subject:               j['subject'] as String?,
    description:           j['description'] as String?,
    from:                  j['from'] as String?,
    to:                    j['to'] as String?,
    forwardedTo:           j['forwarded_to'] as String?,
    status:                j['status'] as String?,
    approvalStatus:        j['approval_status'] as String?,
    priority:              j['priority'] as String?,
    isPaymentInvolved:     j['is_payment_involved'] as String?,
    amount:                (j['amount'] as num?)?.toDouble(),
    recommendedAmount:     (j['recommended_amount'] as num?)?.toDouble(),
    sanctionedAmount:      (j['sanctioned_amount'] as num?)?.toDouble(),
    approvalSequence:      List<String>.from(j['approval_sequence'] ?? []),
    currentSequenceIndex:  (j['current_sequence_index'] as num?)?.toInt() ?? 0,
    currentApprover:       j['current_approver'] as String?,
    approvalProgressPct:   (j['approval_progress_pct'] as num?)?.toInt() ?? 0,
    isFullyApproved:       j['is_fully_approved'] == true,
    createdBy:             j['created_by'] as String?,
    createdByDept:         j['created_by_dept'] as String?,
    createdAt:             j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
    updatedAt:             j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
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
