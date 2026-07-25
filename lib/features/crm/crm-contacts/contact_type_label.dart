/// Web `TYPE_LABELS` for contact_type.
String contactTypeLabel(String type) {
  switch (type) {
    case 'organization':
      return 'Organization';
    case 'prospect':
      return 'Prospect';
    default:
      return 'Contact';
  }
}

const kCrmContactTypes = <String>['contact', 'organization', 'prospect'];
