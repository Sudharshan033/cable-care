import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => const ModuleListPage(
    config: ModuleConfig(
      title: 'Notifications',
      table: 'notifications',
      columns: ['recipient_phone', 'channel', 'status', 'sent_at'],
      searchColumns: ['recipient_phone', 'message'],
      statusColumn: 'status',
    ),
  );
}
