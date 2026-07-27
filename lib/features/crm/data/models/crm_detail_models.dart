import 'package:equatable/equatable.dart';

/// Activity type from CRM config (used by follow-ups + activities).
class CrmActivityType extends Equatable {
  const CrmActivityType({
    required this.id,
    required this.name,
    this.icon = '',
    this.color = '',
    this.position = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String icon;
  final String color;
  final int position;
  final bool isActive;

  factory CrmActivityType.fromJson(Map<String, dynamic> json) =>
      CrmActivityType(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        color: json['color'] as String? ?? '',
        position: (json['position'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [id, name];
}

class CrmTimelineEvent extends Equatable {
  const CrmTimelineEvent({
    required this.id,
    required this.leadId,
    required this.contactId,
    required this.kind,
    required this.summary,
    required this.createdAt,
    this.refId,
    this.actorUserId = '',
    this.actorName,
    this.contactName,
    this.toStageId,
    this.description = '',
    this.note = '',
  });

  final String id;
  final String leadId;
  final String contactId;
  final String kind;
  final String summary;
  final String createdAt;
  final String? refId;
  final String actorUserId;
  final String? actorName;
  final String? contactName;
  final String? toStageId;
  final String description;
  final String note;

  factory CrmTimelineEvent.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'];
    String? toStage;
    if (meta is Map) {
      toStage = meta['to_stage_id']?.toString();
    }
    return CrmTimelineEvent(
      id: json['id'] as String? ?? '',
      leadId: json['lead_id'] as String? ?? '',
      contactId: json['contact_id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      refId: json['ref_id'] as String?,
      actorUserId: json['actor_user_id'] as String? ?? '',
      actorName: json['actor_name'] as String?,
      contactName: json['contact_name'] as String?,
      toStageId: toStage,
      description: json['description'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, kind, createdAt, description, note];
}

class CrmNote extends Equatable {
  const CrmNote({
    required this.id,
    required this.leadId,
    required this.contactId,
    required this.body,
    required this.createdAt,
    this.authorUserId = '',
    this.authorName,
  });

  final String id;
  final String leadId;
  final String contactId;
  final String body;
  final String createdAt;
  final String authorUserId;
  final String? authorName;

  factory CrmNote.fromJson(Map<String, dynamic> json) => CrmNote(
    id: json['id'] as String? ?? '',
    leadId: json['lead_id'] as String? ?? '',
    contactId: json['contact_id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    authorUserId: json['author_user_id'] as String? ?? '',
    authorName: json['author_name'] as String?,
  );

  @override
  List<Object?> get props => [id, body];
}

class CrmActivity extends Equatable {
  const CrmActivity({
    required this.id,
    required this.leadId,
    required this.contactId,
    this.activityTypeId,
    this.subject = '',
    this.body = '',
    this.occurredAt = '',
    this.actorName,
    this.activityTypeName,
  });

  final String id;
  final String leadId;
  final String contactId;
  final String? activityTypeId;
  final String subject;
  final String body;
  final String occurredAt;
  final String? actorName;
  final String? activityTypeName;

  factory CrmActivity.fromJson(Map<String, dynamic> json) => CrmActivity(
    id: json['id'] as String? ?? '',
    leadId: json['lead_id'] as String? ?? '',
    contactId: json['contact_id'] as String? ?? '',
    activityTypeId: json['activity_type_id'] as String?,
    subject: json['subject'] as String? ?? '',
    body: json['body'] as String? ?? '',
    occurredAt: json['occurred_at'] as String? ?? '',
    actorName: json['actor_name'] as String?,
    activityTypeName: json['activity_type_name'] as String?,
  );

  @override
  List<Object?> get props => [id, subject];
}

class CrmActivityInput {
  const CrmActivityInput({
    this.activityTypeId,
    this.subject = '',
    this.body = '',
  });

  final String? activityTypeId;
  final String subject;
  final String body;

  Map<String, dynamic> toJson() => {
    'activity_type_id': activityTypeId,
    'subject': subject,
    'body': body,
  };
}

class CrmFollowup extends Equatable {
  const CrmFollowup({
    required this.id,
    required this.leadId,
    required this.contactId,
    required this.scheduledAt,
    this.stageId,
    this.assignedUserId,
    this.activityTypeId,
    this.priority = 'medium',
    this.status = 'pending',
    this.outcome = '',
    this.notes = '',
    this.createdBy = '',
    this.completedAt,
    this.assigneeName,
    this.activityTypeName,
    this.contactName,
    this.contactCompany,
    this.contactPhone,
    this.stageName,
    this.stageColor,
  });

  final String id;
  final String leadId;
  final String contactId;
  final String scheduledAt;
  final String? stageId;
  final String? assignedUserId;
  final String? activityTypeId;
  final String priority;
  final String status;
  final String outcome;
  final String notes;
  final String createdBy;
  final String? completedAt;
  final String? assigneeName;
  final String? activityTypeName;
  final String? contactName;
  final String? contactCompany;
  final String? contactPhone;
  final String? stageName;
  final String? stageColor;

  bool get isPending => status == 'pending';

  factory CrmFollowup.fromJson(Map<String, dynamic> json) => CrmFollowup(
    id: json['id'] as String? ?? '',
    leadId: json['lead_id'] as String? ?? '',
    contactId: json['contact_id'] as String? ?? '',
    scheduledAt: json['scheduled_at'] as String? ?? '',
    stageId: json['stage_id'] as String?,
    assignedUserId: json['assigned_user_id'] as String?,
    activityTypeId: json['activity_type_id'] as String?,
    priority: json['priority'] as String? ?? 'medium',
    status: json['status'] as String? ?? 'pending',
    outcome: json['outcome'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    createdBy: json['created_by'] as String? ?? '',
    completedAt: json['completed_at'] as String?,
    assigneeName: json['assignee_name'] as String?,
    activityTypeName: json['activity_type_name'] as String?,
    contactName: json['contact_name'] as String?,
    contactCompany: json['contact_company'] as String?,
    contactPhone: json['contact_phone'] as String?,
    stageName: json['stage_name'] as String?,
    stageColor: json['stage_color'] as String?,
  );

  @override
  List<Object?> get props => [id, status, scheduledAt, stageId];
}

class CrmFollowupInput {
  const CrmFollowupInput({
    required this.leadId,
    required this.scheduledAt,
    this.stageId,
    this.activityTypeId,
    this.priority = 'medium',
    this.notes = '',
  });

  final String leadId;
  final String scheduledAt;
  final String? stageId;
  final String? activityTypeId;
  final String priority;
  final String notes;

  Map<String, dynamic> toJson() => {
    'lead_id': leadId,
    'scheduled_at': scheduledAt,
    'priority': priority,
    'notes': notes,
    if (stageId != null && stageId!.isNotEmpty) 'stage_id': stageId,
    if (activityTypeId != null) 'activity_type_id': activityTypeId,
    // Assignee omitted — server inherits lead owner (web parity).
  };
}

class CrmFollowupPatch {
  const CrmFollowupPatch({
    this.scheduledAt,
    this.stageId,
    this.activityTypeId,
    this.priority,
    this.notes,
    this.status,
    this.outcome,
    this.assignedUserId,
  });

  final String? scheduledAt;
  final String? stageId;
  final String? activityTypeId;
  final String? priority;
  final String? notes;
  final String? status;
  final String? outcome;
  final String? assignedUserId;

  Map<String, dynamic> toJson() => {
    if (scheduledAt != null) 'scheduled_at': scheduledAt,
    if (stageId != null) 'stage_id': stageId,
    if (activityTypeId != null) 'activity_type_id': activityTypeId,
    if (priority != null) 'priority': priority,
    if (notes != null) 'notes': notes,
    if (status != null) 'status': status,
    if (outcome != null) 'outcome': outcome,
    if (assignedUserId != null) 'assigned_user_id': assignedUserId,
  };
}

class CrmDocument extends Equatable {
  const CrmDocument({
    required this.id,
    required this.leadId,
    required this.contactId,
    required this.fileUrl,
    required this.fileName,
    this.label = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.createdAt = '',
    this.uploaderName,
  });

  final String id;
  final String leadId;
  final String contactId;
  final String fileUrl;
  final String fileName;
  final String label;
  final String mimeType;
  final int sizeBytes;
  final String createdAt;
  final String? uploaderName;

  bool get isAudio {
    if (mimeType.toLowerCase().startsWith('audio/')) return true;
    return RegExp(
      r'\.(m4a|aac|mp3|ogg|opus|wav|webm)$',
      caseSensitive: false,
    ).hasMatch(fileName);
  }

  bool get isPdf {
    final mt = mimeType.toLowerCase();
    if (mt == 'application/pdf' || mt == 'application/x-pdf') return true;
    return fileName.toLowerCase().endsWith('.pdf');
  }

  factory CrmDocument.fromJson(Map<String, dynamic> json) => CrmDocument(
    id: json['id'] as String? ?? '',
    leadId: json['lead_id'] as String? ?? '',
    contactId: json['contact_id'] as String? ?? '',
    fileUrl: json['file_url'] as String? ?? '',
    fileName: json['file_name'] as String? ?? '',
    label: json['label'] as String? ?? '',
    mimeType: json['mime_type'] as String? ?? '',
    sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] as String? ?? '',
    uploaderName: json['uploader_name'] as String?,
  );

  @override
  List<Object?> get props => [id, fileName];
}

class CrmDocumentPresign {
  const CrmDocumentPresign({
    required this.uploadUrl,
    required this.publicUrl,
    this.objectKey = '',
  });

  final String uploadUrl;
  final String publicUrl;
  final String objectKey;

  factory CrmDocumentPresign.fromJson(Map<String, dynamic> json) =>
      CrmDocumentPresign(
        uploadUrl: json['upload_url'] as String? ?? '',
        publicUrl: json['public_url'] as String? ?? '',
        objectKey: json['object_key'] as String? ?? '',
      );
}

class CrmOrganizationDocument extends Equatable {
  const CrmOrganizationDocument({
    required this.id,
    required this.organizationId,
    this.title = '',
    this.description = '',
    this.fileUrl = '',
    this.externalUrl = '',
    this.fileName = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.createdAt = '',
    this.uploaderName,
  });

  final String id;
  final String organizationId;
  final String title;
  final String description;
  final String fileUrl;
  final String externalUrl;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String createdAt;
  final String? uploaderName;

  String get url => fileUrl.isNotEmpty ? fileUrl : externalUrl;

  bool get isAudio {
    if (mimeType.toLowerCase().startsWith('audio/')) return true;
    return RegExp(
      r'\.(m4a|aac|mp3|ogg|opus|wav|webm)$',
      caseSensitive: false,
    ).hasMatch(fileName);
  }

  bool get isPdf {
    final mt = mimeType.toLowerCase();
    if (mt == 'application/pdf' || mt == 'application/x-pdf') return true;
    return fileName.toLowerCase().endsWith('.pdf');
  }

  factory CrmOrganizationDocument.fromJson(Map<String, dynamic> json) =>
      CrmOrganizationDocument(
        id: json['id'] as String? ?? '',
        organizationId: json['organization_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        fileUrl: json['file_url'] as String? ?? '',
        externalUrl: json['external_url'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        mimeType: json['mime_type'] as String? ?? '',
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] as String? ?? '',
        uploaderName: json['uploader_name'] as String?,
      );

  @override
  List<Object?> get props => [id, fileUrl, externalUrl];
}
