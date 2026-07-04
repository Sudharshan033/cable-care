import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (
        'Customer',
        ModuleConfig(
          title: 'Customer Report',
          table: 'customers',
          columns: ['customer_code', 'name', 'phone', 'status'],
          searchColumns: ['name', 'phone'],
          statusColumn: 'status',
        ),
      ),
      (
        'Collection',
        ModuleConfig(
          title: 'Collection Report',
          table: 'payments',
          columns: ['receipt_number', 'amount', 'payment_method', 'created_at'],
          searchColumns: ['receipt_number'],
        ),
      ),
      (
        'Expense',
        ModuleConfig(
          title: 'Expense Report',
          table: 'expenses',
          columns: ['expense_date', 'category', 'amount', 'paid_to'],
          searchColumns: ['category', 'paid_to'],
        ),
      ),
      (
        'Complaint',
        ModuleConfig(
          title: 'Complaint Report',
          table: 'complaints',
          columns: ['complaint_number', 'priority', 'status', 'created_at'],
          searchColumns: ['complaint_number'],
          statusColumn: 'status',
        ),
      ),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          const PageHeader(
            title: 'Reports',
            subtitle: 'Filtered tables with export-ready data.',
          ),
          const SizedBox(height: 8),
          TabBar(tabs: [for (final tab in tabs) Tab(text: tab.$1)]),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                for (final tab in tabs) ModuleListPage(config: tab.$2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
