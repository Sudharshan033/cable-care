import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class ComplaintsPage extends StatelessWidget {
  const ComplaintsPage({super.key});
  @override
  Widget build(BuildContext context) => const ModuleListPage(
    config: ModuleConfig(
      title: 'Complaints',
      table: 'complaints',
      columns: [
        'complaint_number',
        'phone',
        'complaint_type',
        'priority',
        'status',
      ],
      searchColumns: ['complaint_number', 'phone', 'description'],
      statusColumn: 'status',
    ),
  );
}
