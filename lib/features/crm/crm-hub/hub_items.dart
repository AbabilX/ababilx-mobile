import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';

/// One hub tile — id used later for real routes.
class CrmHubItem {
  const CrmHubItem({
    required this.id,
    required this.labelKey,
    required this.icon,
    required this.color,
  });

  final String id;
  final String labelKey;
  final List<List<dynamic>> icon;
  final Color color;
}

/// Section of hub tiles.
class CrmHubSectionData {
  const CrmHubSectionData({
    required this.titleKey,
    required this.items,
  });

  final String titleKey;
  final List<CrmHubItem> items;
}

/// Static AbabilX CRM hub catalog (Phase 1 shell).
const List<CrmHubSectionData> kCrmHubSections = [
  CrmHubSectionData(
    titleKey: 'crm_section_customer',
    items: [
      CrmHubItem(
        id: 'contacts',
        labelKey: 'crm_contacts',
        icon: HugeIcons.strokeRoundedUserGroup,
        color: AppColors.green,
      ),
      CrmHubItem(
        id: 'leads',
        labelKey: 'crm_leads',
        icon: HugeIcons.strokeRoundedBriefcase01,
        color: Color(0xFF14B8A6),
      ),
      CrmHubItem(
        id: 'followups',
        labelKey: 'crm_followups',
        icon: HugeIcons.strokeRoundedTask01,
        color: Color(0xFF0EA5E9),
      ),
    ],
  ),
  CrmHubSectionData(
    titleKey: 'crm_section_overview',
    items: [
      CrmHubItem(
        id: 'dashboard',
        labelKey: 'crm_dashboard',
        icon: HugeIcons.strokeRoundedDashboardSquare01,
        color: AppColors.indigo,
      ),
      CrmHubItem(
        id: 'calendar',
        labelKey: 'crm_calendar',
        icon: HugeIcons.strokeRoundedCalendar01,
        color: Color(0xFFF97316),
      ),
      CrmHubItem(
        id: 'timeline',
        labelKey: 'crm_timeline',
        icon: HugeIcons.strokeRoundedClock01,
        color: Color(0xFFA855F7),
      ),
      CrmHubItem(
        id: 'reports',
        labelKey: 'crm_reports',
        icon: HugeIcons.strokeRoundedAnalytics01,
        color: Color(0xFFEC4899),
      ),
    ],
  ),
  CrmHubSectionData(
    titleKey: 'crm_section_setup',
    items: [
      CrmHubItem(
        id: 'settings',
        labelKey: 'crm_settings',
        icon: HugeIcons.strokeRoundedSettings01,
        color: AppColors.amber,
      ),
    ],
  ),
];
