import 'package:hugeicons/hugeicons.dart';

/// One hub tile — id used later for real routes.
class CrmHubItem {
  const CrmHubItem({
    required this.id,
    required this.labelKey,
    required this.icon,
  });

  final String id;
  final String labelKey;
  final List<List<dynamic>> icon;
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

/// Static AbabilX CRM hub catalog.
const List<CrmHubSectionData> kCrmHubSections = [
  CrmHubSectionData(
    titleKey: 'crm_section_customer',
    items: [
      CrmHubItem(
        id: 'contacts',
        labelKey: 'crm_contacts',
        icon: HugeIcons.strokeRoundedUserGroup,
      ),
      CrmHubItem(
        id: 'leads',
        labelKey: 'crm_leads',
        icon: HugeIcons.strokeRoundedBriefcase01,
      ),
      CrmHubItem(
        id: 'followups',
        labelKey: 'crm_followups',
        icon: HugeIcons.strokeRoundedTask01,
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
      ),
      CrmHubItem(
        id: 'calendar',
        labelKey: 'crm_calendar',
        icon: HugeIcons.strokeRoundedCalendar01,
      ),
      CrmHubItem(
        id: 'timeline',
        labelKey: 'crm_timeline',
        icon: HugeIcons.strokeRoundedClock01,
      ),
      CrmHubItem(
        id: 'reports',
        labelKey: 'crm_reports',
        icon: HugeIcons.strokeRoundedAnalytics01,
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
      ),
    ],
  ),
];
