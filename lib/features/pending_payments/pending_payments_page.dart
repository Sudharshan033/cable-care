import 'package:cableapp/features/notifications/notification_service.dart';
import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class PendingPaymentsPage extends StatelessWidget {
  const PendingPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: const ModuleListPage(
            config: ModuleConfig(
              title: 'Pending Payments',
              subtitle: 'Buckets for 1, 2, 3, and 6 month pending collections.',
              table: 'monthly_bills',
              columns: [
                'customer_id',
                'bill_month',
                'bill_year',
                'total_amount',
                'status',
              ],
              searchColumns: ['customer_id', 'bill_month', 'bill_year'],
              statusColumn: 'status',
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: FloatingActionButton.extended(
            onPressed: () async {
              await NotificationService().sendWhatsApp(
                phone: '0000000000',
                message: 'CableCare payment reminder queued from admin panel.',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reminder queued')),
                );
              }
            },
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Send reminder'),
          ),
        ),
      ],
    );
  }
}
