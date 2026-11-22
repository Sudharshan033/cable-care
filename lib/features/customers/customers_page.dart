import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      config: ModuleConfig(
        title: 'Customers',
        subtitle:
            'Search, filter, export, import, suspend, reconnect, and open customer history.',
        table: 'customers',
        columns: [
          'customer_code',
          'name',
          'phone',
          'box_id',
          'village',
          'monthly_charge',
          'status',
        ],
        searchColumns: [
          'customer_code',
          'name',
          'phone',
          'box_id',
          'vc_number',
          'smart_card_number',
          'village',
        ],
        statusColumn: 'status',
        addPath: '/customers/new',
        importColumns: [
          'name',
          'phone',
          'alternate_number',
          'email',
          'address',
          'village',
          'pincode',
          'box_id',
          'vc_number',
          'smart_card_number',
          'monthly_charge',
          'installation_charge',
          'security_deposit',
          'status',
          'notes',
        ],
      ),
    );
  }
}
