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
  const CrmHubSectionData({required this.titleKey, required this.items});

  final String titleKey;
  final List<CrmHubItem> items;
}

/// Static AbabilX CRM hub catalog — customer shortcuts only.
const List<CrmHubSectionData> kCrmHubSections = [
  CrmHubSectionData(
    titleKey: 'crm_section_customer',
    items: [
      CrmHubItem(
        id: 'organizations',
        labelKey: 'crm_organizations',
        icon: HugeIcons.strokeRoundedBuilding03,
      ),
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
];
