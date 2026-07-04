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
            'Search, filter, export, suspend, reconnect, and open customer history.',
        table: 'customers',
        columns: [
          'customer_code',
          'name',
          'phone',
          'village',
          'monthly_charge',
          'status',
        ],
        searchColumns: [
          'customer_code',
          'name',
          'phone',
          'vc_number',
          'smart_card_number',
        ],
        statusColumn: 'status',
        addPath: '/customers/new',
      ),
    );
  }
}
