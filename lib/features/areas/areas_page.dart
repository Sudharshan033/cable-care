import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class AreasPage extends StatelessWidget {
  const AreasPage({super.key});
  @override
  Widget build(BuildContext context) => const ModuleListPage(
    config: ModuleConfig(
      title: 'Areas',
      table: 'areas',
      columns: [
        'name',
        'code',
        'customer_count',
        'pending_amount',
        'monthly_collection',
      ],
      searchColumns: ['name', 'code'],
    ),
  );
}
