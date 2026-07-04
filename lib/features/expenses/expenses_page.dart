import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});
  @override
  Widget build(BuildContext context) => const ModuleListPage(
    config: ModuleConfig(
      title: 'Expenses',
      table: 'expenses',
      columns: [
        'expense_date',
        'category',
        'amount',
        'paid_to',
        'payment_method',
      ],
      searchColumns: ['category', 'paid_to', 'notes'],
    ),
  );
}
