import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'crm_config_api.dart';
import 'crm_contacts_api.dart';
import 'models/crm_models.dart';

class CrmRepository {
  CrmRepository(ApiClient client)
      : contacts = CrmContactsApi(client),
        config = CrmConfigApi(client);

  final CrmContactsApi contacts;
  final CrmConfigApi config;

  Future<List<CrmContact>> listContacts({String? q}) =>
      contacts.list(q: q);

  Future<CrmContact> createContact(CrmContactInput body) =>
      contacts.create(body);

  Future<CrmContact> updateContact(String id, CrmContactInput body) =>
      contacts.update(id, body);

  Future<void> deleteContact(String id) => contacts.delete(id);

  Future<CrmConfig> getConfig() => config.get();
}

final crmRepositoryProvider = Provider<CrmRepository>(
  (ref) => CrmRepository(ref.watch(apiClientProvider)),
);
