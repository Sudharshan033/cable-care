import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class TechniciansPage extends StatelessWidget {
  const TechniciansPage({super.key});
  @override
  Widget build(BuildContext context) => const ModuleListPage(
    config: ModuleConfig(
      title: 'Technicians',
      table: 'technicians',
      columns: [
        'name',
        'phone',
        'jobs_count',
        'completed_count',
        'pending_count',
      ],
      searchColumns: ['name', 'phone'],
    ),
  );
}
