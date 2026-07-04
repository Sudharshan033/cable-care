import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class BillingPage extends StatelessWidget {
  const BillingPage({super.key});
  @override
  Widget build(BuildContext context) => const ModuleListPage(
    config: ModuleConfig(
      title: 'Monthly Bills',
      table: 'monthly_bills',
      columns: [
        'bill_month',
        'bill_year',
        'amount',
        'previous_due',
        'total_amount',
        'status',
      ],
      searchColumns: ['bill_month', 'bill_year'],
      statusColumn: 'status',
    ),
  );
}
