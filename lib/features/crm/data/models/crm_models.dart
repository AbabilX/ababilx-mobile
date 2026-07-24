import 'package:equatable/equatable.dart';

import 'crm_detail_models.dart';
export 'crm_detail_models.dart';

/// Per-module grant set (matches backend `ModuleActions` JSON).
class ModuleActions extends Equatable {
  const ModuleActions({
    this.view = false,
    this.create = false,
    this.update = false,
    this.delete = false,
    this.configure = false,
  });

  final bool view;
  final bool create;
  final bool update;
  final bool delete;
  final bool configure;

  static const none = ModuleActions();

  factory ModuleActions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return none;
    return ModuleActions(
      view: json['view'] as bool? ?? false,
      create: json['create'] as bool? ?? false,
      update: json['update'] as bool? ?? false,
      delete: json['delete'] as bool? ?? false,
      configure: json['configure'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [view, create, update, delete, configure];
}

/// Web-parity CRM action gates: access ∧ module grant.
class CrmPerms extends Equatable {
  const CrmPerms({
    required this.access,
    required this.create,
    required this.update,
    required this.delete,
    required this.configure,
  });

  final bool access;
  final bool create;
  final bool update;
  final bool delete;
  final bool configure;

  bool get view => access;

  static const none = CrmPerms(
    access: false,
    create: false,
    update: false,
    delete: false,
    configure: false,
  );

  factory CrmPerms.resolve({
    required bool canViewCrm,
    ModuleActions? grants,
  }) {
    final g = grants ?? ModuleActions.none;
    return CrmPerms(
      access: canViewCrm,
      create: canViewCrm && g.create,
      update: canViewCrm && g.update,
      delete: canViewCrm && g.delete,
      configure: canViewCrm && g.configure,
    );
  }

  @override
  List<Object?> get props => [access, create, update, delete, configure];
}

class CrmSettings extends Equatable {
  const CrmSettings({
    this.contactLabelSingular = 'Contact',
    this.contactLabelPlural = 'Contacts',
    this.currency = 'BDT',
  });

  final String contactLabelSingular;
  final String contactLabelPlural;
  final String currency;

  factory CrmSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CrmSettings();
    return CrmSettings(
      contactLabelSingular:
          json['contact_label_singular'] as String? ?? 'Contact',
      contactLabelPlural: json['contact_label_plural'] as String? ?? 'Contacts',
      currency: json['currency'] as String? ?? 'BDT',
    );
  }

  @override
  List<Object?> get props =>
      [contactLabelSingular, contactLabelPlural, currency];
}

class CrmFieldDef extends Equatable {
  const CrmFieldDef({
    required this.id,
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.required = false,
  });

  final String id;
  final String key;
  final String label;
  final String type;
  final List<String> options;
  final bool required;

  factory CrmFieldDef.fromJson(Map<String, dynamic> json) => CrmFieldDef(
        id: json['id'] as String? ?? '',
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        type: json['type'] as String? ?? 'text',
        options: (json['options'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        required: json['required'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, key];
}

class CrmStage extends Equatable {
  const CrmStage({
    required this.id,
    required this.pipelineId,
    required this.name,
    this.color = '',
    this.position = 0,
    this.isWon = false,
    this.isLost = false,
  });

  final String id;
  final String pipelineId;
  final String name;
  final String color;
  final int position;
  final bool isWon;
  final bool isLost;

  factory CrmStage.fromJson(Map<String, dynamic> json) => CrmStage(
        id: json['id'] as String? ?? '',
        pipelineId: json['pipeline_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '',
        position: (json['position'] as num?)?.toInt() ?? 0,
        isWon: json['is_won'] as bool? ?? false,
        isLost: json['is_lost'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, name, position];
}

class CrmPipeline extends Equatable {
  const CrmPipeline({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.position = 0,
    this.stages = const [],
  });

  final String id;
  final String name;
  final bool isDefault;
  final int position;
  final List<CrmStage> stages;

  factory CrmPipeline.fromJson(Map<String, dynamic> json) {
    final stages = (json['stages'] as List<dynamic>? ?? [])
        .map((e) => CrmStage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return CrmPipeline(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      position: (json['position'] as num?)?.toInt() ?? 0,
      stages: stages,
    );
  }

  @override
  List<Object?> get props => [id, name, stages.length];
}

class CrmConfig extends Equatable {
  const CrmConfig({
    this.settings = const CrmSettings(),
    this.pipelines = const [],
    this.activityTypes = const [],
    this.fields = const [],
  });

  final CrmSettings settings;
  final List<CrmPipeline> pipelines;
  final List<CrmActivityType> activityTypes;
  final List<CrmFieldDef> fields;

  CrmPipeline? get defaultPipeline {
    for (final p in pipelines) {
      if (p.isDefault) return p;
    }
    return pipelines.isEmpty ? null : pipelines.first;
  }

  factory CrmConfig.fromJson(Map<String, dynamic> json) => CrmConfig(
        settings: CrmSettings.fromJson(
          json['settings'] as Map<String, dynamic>?,
        ),
        pipelines: (json['pipelines'] as List<dynamic>? ?? [])
            .map((e) => CrmPipeline.fromJson(e as Map<String, dynamic>))
            .toList(),
        activityTypes: (json['activity_types'] as List<dynamic>? ?? [])
            .map((e) => CrmActivityType.fromJson(e as Map<String, dynamic>))
            .where((a) => a.isActive)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
        fields: (json['fields'] as List<dynamic>? ?? [])
            .map((e) => CrmFieldDef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props =>
      [settings, pipelines.length, activityTypes.length, fields.length];
}

class CrmContact extends Equatable {
  const CrmContact({
    required this.id,
    required this.teamId,
    this.ownerUserId,
    required this.name,
    this.email = '',
    this.phone = '',
    this.company = '',
    this.source = '',
    this.tags = const [],
    this.customFields = const {},
    this.createdBy = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.ownerName,
    this.leadCount = 0,
    this.totalValue = 0,
  });

  final String id;
  final String teamId;
  final String? ownerUserId;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String source;
  final List<String> tags;
  final Map<String, dynamic> customFields;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final String? ownerName;
  final int leadCount;
  final double totalValue;

  factory CrmContact.fromJson(Map<String, dynamic> json) {
    final custom = json['custom_fields'];
    return CrmContact(
      id: json['id'] as String? ?? '',
      teamId: json['team_id'] as String? ?? '',
      ownerUserId: json['owner_user_id'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      company: json['company'] as String? ?? '',
      source: json['source'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      customFields: custom is Map
          ? Map<String, dynamic>.from(custom)
          : const {},
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      ownerName: json['owner_name'] as String?,
      leadCount: (json['lead_count'] as num?)?.toInt() ?? 0,
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, updatedAt];
}

class CrmContactInput {
  const CrmContactInput({
    required this.name,
    this.email = '',
    this.phone = '',
    this.company = '',
    this.source = '',
    this.tags = const [],
    this.ownerUserId,
    this.unassignedOwner = false,
    this.customFields = const {},
  });

  final String name;
  final String email;
  final String phone;
  final String company;
  final String source;
  final List<String> tags;
  final String? ownerUserId;
  /// When true, sends `owner_user_id: null` (Unassigned).
  final bool unassignedOwner;
  final Map<String, dynamic> customFields;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'company': company,
        'source': source,
        'tags': tags,
        'custom_fields': customFields,
        if (unassignedOwner)
          'owner_user_id': null
        else if (ownerUserId != null)
          'owner_user_id': ownerUserId,
      };
}

/// Deal/opportunity under a contact (web `CRMLead`).
class CrmLead extends Equatable {
  const CrmLead({
    required this.id,
    required this.teamId,
    required this.contactId,
    this.pipelineId,
    this.stageId,
    this.ownerUserId,
    required this.title,
    this.dealValue = 0,
    this.source = '',
    this.customFields = const {},
    this.createdBy = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.contactName,
    this.contactCompany,
    this.contactPhone,
    this.contactEmail,
    this.stageName,
    this.stageColor,
    this.ownerName,
    this.isWon = false,
    this.isLost = false,
  });

  final String id;
  final String teamId;
  final String contactId;
  final String? pipelineId;
  final String? stageId;
  final String? ownerUserId;
  final String title;
  final double dealValue;
  final String source;
  final Map<String, dynamic> customFields;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final String? contactName;
  final String? contactCompany;
  final String? contactPhone;
  final String? contactEmail;
  final String? stageName;
  final String? stageColor;
  final String? ownerName;
  final bool isWon;
  final bool isLost;

  factory CrmLead.fromJson(Map<String, dynamic> json) {
    final custom = json['custom_fields'];
    return CrmLead(
      id: json['id'] as String? ?? '',
      teamId: json['team_id'] as String? ?? '',
      contactId: json['contact_id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String?,
      stageId: json['stage_id'] as String?,
      ownerUserId: json['owner_user_id'] as String?,
      title: json['title'] as String? ?? '',
      dealValue: (json['deal_value'] as num?)?.toDouble() ?? 0,
      source: json['source'] as String? ?? '',
      customFields: custom is Map
          ? Map<String, dynamic>.from(custom)
          : const {},
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      contactName: json['contact_name'] as String?,
      contactCompany: json['contact_company'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      stageName: json['stage_name'] as String?,
      stageColor: json['stage_color'] as String?,
      ownerName: json['owner_name'] as String?,
      isWon: json['is_won'] as bool? ?? false,
      isLost: json['is_lost'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, title, updatedAt];
}

class CrmLeadInput {
  const CrmLeadInput({
    this.pipelineId,
    this.stageId,
    this.ownerUserId,
    this.unassignedOwner = false,
    this.title = '',
    this.dealValue = 0,
    this.source = '',
    this.customFields = const {},
  });

  final String? pipelineId;
  final String? stageId;
  final String? ownerUserId;
  final bool unassignedOwner;
  final String title;
  final double dealValue;
  final String source;
  final Map<String, dynamic> customFields;

  Map<String, dynamic> toJson() => {
        'title': title,
        'deal_value': dealValue,
        'source': source,
        'custom_fields': customFields,
        'pipeline_id': pipelineId,
        'stage_id': stageId,
        if (unassignedOwner)
          'owner_user_id': null
        else if (ownerUserId != null)
          'owner_user_id': ownerUserId,
      };
}

/// Result from lead create/edit sheet.
class CrmLeadFormResult {
  const CrmLeadFormResult({
    required this.lead,
    this.contactId,
    this.newContact,
  });

  final CrmLeadInput lead;
  final String? contactId;
  final CrmContactInput? newContact;
}
