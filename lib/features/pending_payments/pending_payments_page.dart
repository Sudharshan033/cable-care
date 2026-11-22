import 'package:cableapp/core/services/unit_service.dart';
import 'package:cableapp/core/utils/file_download.dart';
import 'package:cableapp/core/utils/formatters.dart';
import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/core/widgets/status_badge.dart';
import 'package:cableapp/data/supabase_client.dart';
import 'package:cableapp/features/notifications/notification_service.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _pendingBillsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final activeUnit = ref.watch(activeUnitIdProvider);
  final response = await supabase
      .from('monthly_bills')
      .select('*, customers(name, phone, box_id, customer_code, village, area_id)')
      .neq('status', 'paid')
      .order('bill_year', ascending: false)
      .order('bill_month', ascending: false);

  final list = (response as List).cast<Map<String, dynamic>>();
  if (activeUnit == null) return list;
  return list.where((b) => b['customers']?['area_id'] == activeUnit).toList();
});

class PendingPaymentsPage extends ConsumerStatefulWidget {
  const PendingPaymentsPage({super.key});

  @override
  ConsumerState<PendingPaymentsPage> createState() =>
      _PendingPaymentsPageState();
}

class _PendingPaymentsPageState extends ConsumerState<PendingPaymentsPage> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(_pendingBillsProvider);

    return Scaffold(
      floatingActionButton: pendingAsync.maybeWhen(
        data: (bills) => bills.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showBulkReminderDialog(context, bills),
                icon: const Icon(Icons.campaign_outlined),
                label: Text('Send reminder (${bills.length})'),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
        orElse: () => null,
      ),
      body: ListView(
        children: [
          const PageHeader(
            title: 'Pending Payments',
            subtitle:
                'Customers with unpaid monthly dues. Send individual or bulk payment reminders.',
          ),
          const SizedBox(height: 16),

          // Overview Metric Card
          pendingAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (bills) {
              final totalDue = bills.fold<num>(
                0,
                (sum, b) =>
                    sum +
                    (num.tryParse(
                            '${b['total_amount'] ?? b['amount'] ?? 0}') ??
                        0),
              );

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pending_actions_outlined,
                          color: Colors.orange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Pending Collection',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            money(totalDue),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${bills.length} Customer(s) Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Search & Export Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, or Box ID...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (val) => setState(() => search = val.trim()),
                    ),
                  ),
                  const Spacer(),
                  pendingAsync.whenOrNull(
                        data: (bills) => OutlinedButton.icon(
                          onPressed: bills.isEmpty
                              ? null
                              : () => _exportExcel(bills),
                          icon: const Icon(Icons.file_download_outlined),
                          label: const Text('Export Excel'),
                        ),
                      ) ??
                      const SizedBox.shrink(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Pending Bills Table
          pendingAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) =>
                Center(child: Text('Error loading pending bills: $e')),
            data: (bills) {
              var filtered = bills;
              if (search.isNotEmpty) {
                final q = search.toLowerCase();
                filtered = filtered.where((b) {
                  final cust = (b['customers'] as Map?) ?? {};
                  final name = '${cust['name'] ?? ''}'.toLowerCase();
                  final phone = '${cust['phone'] ?? ''}'.toLowerCase();
                  final box = '${cust['box_id'] ?? ''}'.toLowerCase();
                  final code = '${cust['customer_code'] ?? ''}'.toLowerCase();
                  return name.contains(q) ||
                      phone.contains(q) ||
                      box.contains(q) ||
                      code.contains(q);
                }).toList();
              }

              if (filtered.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48, color: Colors.green),
                          SizedBox(height: 8),
                          Text(
                            'No pending bills! All customers are up to date.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Box ID')),
                      DataColumn(label: Text('Bill Period')),
                      DataColumn(label: Text('Current Bill')),
                      DataColumn(label: Text('Prev Due')),
                      DataColumn(label: Text('Total Due')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Send Reminder')),
                    ],
                    rows: filtered.map((b) {
                      final cust = (b['customers'] as Map?) ?? {};
                      final name = '${cust['name'] ?? '-'}';
                      final phone = '${cust['phone'] ?? '-'}';
                      final boxId = '${cust['box_id'] ?? '-'}';
                      final code = '${cust['customer_code'] ?? ''}';
                      final month = b['bill_month'] ?? 0;
                      final year = b['bill_year'] ?? 0;
                      final amount = num.tryParse('${b['amount'] ?? 0}') ?? 0;
                      final prevDue =
                          num.tryParse('${b['previous_due'] ?? 0}') ?? 0;
                      final total = num.tryParse('${b['total_amount'] ?? 0}') ??
                          (amount + prevDue);
                      final status = '${b['status'] ?? 'pending'}';

                      return DataRow(cells: [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              if (code.isNotEmpty)
                                Text(code,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        DataCell(Text(phone)),
                        DataCell(
                          boxId != '-'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    boxId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : const Text('-'),
                        ),
                        DataCell(Text('$month / $year')),
                        DataCell(Text(money(amount))),
                        DataCell(Text(money(prevDue))),
                        DataCell(
                          Text(
                            money(total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                        DataCell(StatusBadge(status)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline,
                                    color: Colors.green, size: 20),
                                tooltip: 'WhatsApp Reminder',
                                onPressed: () {
                                  final msg =
                                      '*CableCare Bill Reminder*\n\n'
                                      'Dear $name,\n'
                                      'This is a reminder that your cable TV bill is *Pending*.\n\n'
                                      '━━━━━━━━━━━━━━━━━━━━\n'
                                      '📦 Box ID: $boxId\n'
                                      '📅 Bill Period: $month / $year\n'
                                      '💰 Total Due: ${money(total)}\n'
                                      '━━━━━━━━━━━━━━━━━━━━\n\n'
                                      'Kindly make the payment soon to avoid service interruption.\n'
                                      'Thank you - CableCare!';
                                  NotificationService().openWhatsApp(
                                      phone: phone, message: msg);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.sms_outlined,
                                    color: Colors.blue, size: 20),
                                tooltip: 'SMS Reminder',
                                onPressed: () {
                                  final msg =
                                      'Dear $name, your CableCare bill for $month/$year is ${money(total)}. '
                                      'Box: $boxId. Kindly pay soon. Thank you.';
                                  NotificationService()
                                      .openSMS(phone: phone, message: msg);
                                },
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _showBulkReminderDialog(
      BuildContext context, List<Map<String, dynamic>> bills) async {
    final totalDue = bills.fold<num>(
      0,
      (sum, b) =>
          sum +
          (num.tryParse('${b['total_amount'] ?? b['amount'] ?? 0}') ?? 0),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.campaign_outlined, color: Colors.green, size: 48),
        title: const Text('Broadcast Payment Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send payment reminders to all ${bills.length} pending customer(s)?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Total Outstanding Collection: ${money(totalDue)}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Sample Message:\n'
                '"Dear Customer, your CableCare bill is pending. Kindly pay at the earliest to ensure uninterrupted cable service."',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Queue Reminders'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              int queuedCount = 0;
              for (final b in bills) {
                final cust = (b['customers'] as Map?) ?? {};
                final phone = '${cust['phone'] ?? ''}';
                final name = '${cust['name'] ?? ''}';
                final total = b['total_amount'] ?? b['amount'] ?? 0;
                if (phone.isNotEmpty && phone != '-') {
                  await NotificationService().sendWhatsApp(
                    phone: phone,
                    message:
                        'Dear $name, your CableCare monthly bill of ${money(total)} is pending. Kindly make payment soon.',
                  );
                  queuedCount++;
                }
              }
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        'Successfully queued reminders for $queuedCount customer(s)!'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _exportExcel(List<Map<String, dynamic>> bills) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Pending_Bills'];
    sheet.appendRow([
      TextCellValue('Customer Name'),
      TextCellValue('Phone'),
      TextCellValue('Box ID'),
      TextCellValue('Month'),
      TextCellValue('Year'),
      TextCellValue('Amount'),
      TextCellValue('Previous Due'),
      TextCellValue('Total Due'),
      TextCellValue('Status'),
    ]);
    for (final b in bills) {
      final cust = (b['customers'] as Map?) ?? {};
      sheet.appendRow([
        TextCellValue('${cust['name'] ?? '-'}'),
        TextCellValue('${cust['phone'] ?? '-'}'),
        TextCellValue('${cust['box_id'] ?? '-'}'),
        TextCellValue('${b['bill_month'] ?? ''}'),
        TextCellValue('${b['bill_year'] ?? ''}'),
        TextCellValue('${b['amount'] ?? 0}'),
        TextCellValue('${b['previous_due'] ?? 0}'),
        TextCellValue('${b['total_amount'] ?? 0}'),
        TextCellValue('${b['status'] ?? 'pending'}'),
      ]);
    }
    final bytes = workbook.encode();
    if (bytes == null) return;
    downloadBytes(bytes, 'pending_bills.xlsx');
  }
}
