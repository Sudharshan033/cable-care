import 'package:cableapp/core/services/unit_service.dart';
import 'package:cableapp/core/utils/file_download.dart';
import 'package:cableapp/core/utils/formatters.dart';
import 'package:cableapp/core/widgets/app_paginated_table.dart';
import 'package:cableapp/core/widgets/empty_state.dart';
import 'package:cableapp/core/widgets/error_state.dart';
import 'package:cableapp/core/widgets/loading_skeleton.dart';
import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/core/widgets/status_badge.dart';
import 'package:cableapp/data/models/app_record.dart';
import 'package:cableapp/data/repositories/base_repository.dart';
import 'package:cableapp/data/supabase_client.dart';
import 'package:cableapp/features/notifications/notification_service.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ModuleConfig {
  const ModuleConfig({
    required this.title,
    required this.table,
    required this.columns,
    this.subtitle,
    this.searchColumns = const [],
    this.statusColumn,
    this.addPath,
    this.importColumns,
  });

  final String title;
  final String? subtitle;
  final String table;
  final List<String> columns;
  final List<String> searchColumns;
  final String? statusColumn;
  final String? addPath;

  /// Column names that map to Excel headers during import.
  /// If null, import is disabled for this module.
  final List<String>? importColumns;
}

class ModuleListPage extends ConsumerStatefulWidget {
  const ModuleListPage({required this.config, super.key});
  final ModuleConfig config;

  @override
  ConsumerState<ModuleListPage> createState() => _ModuleListPageState();
}

class _ModuleListPageState extends ConsumerState<ModuleListPage> {
  String search = '';
  List<AppRecord>? _cachedRecords;

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(moduleRowsProvider((widget.config, search)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: widget.config.title,
          subtitle: widget.config.subtitle,
          actions: [
            SizedBox(
              width: 280,
              child: SearchBar(
                leading: const Icon(Icons.search),
                hintText: 'Search',
                onChanged: (value) => setState(() => search = value),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _cachedRecords == null || _cachedRecords!.isEmpty
                  ? null
                  : () => _exportExcel(_cachedRecords!),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export'),
            ),
            if (widget.config.importColumns != null)
              OutlinedButton.icon(
                onPressed: _importExcel,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import'),
              ),
            if (widget.config.addPath != null)
              FilledButton.icon(
                onPressed: () => context.go(widget.config.addPath!),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: rows.when(
            loading: () => const LoadingSkeleton(),
            error: (error, _) => ErrorState(
              message: '$error',
              onRetry: () =>
                  ref.invalidate(moduleRowsProvider((widget.config, search))),
            ),
            data: (records) {
              _cachedRecords = records;
              if (records.isEmpty) {
                return EmptyState(
                  title: 'No ${widget.config.title.toLowerCase()} yet',
                );
              }
              return AppPaginatedTable(
                columns: [
                  for (final column in widget.config.columns)
                    DataColumn(label: Text(_header(column))),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final record in records)
                    DataRow(
                      cells: [
                        for (final column in widget.config.columns)
                          DataCell(
                            widget.config.statusColumn == column
                                ? StatusBadge(record.text(column))
                                : (column == 'name' &&
                                        widget.config.table == 'customers')
                                    ? InkWell(
                                        onTap: () => _showCustomerDetails(record),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Text(
                                            record.text(column),
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.bold,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        record.text(column),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                          ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.config.addPath?.startsWith(
                                        '/customers',
                                      ) ==
                                      true) ...[
                                IconButton(
                                  tooltip: 'View Details',
                                  icon: const Icon(Icons.visibility_outlined,
                                      size: 20),
                                  onPressed: () =>
                                      _showCustomerDetails(record),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () =>
                                      context.go('/customers/${record.id}'),
                                ),
                              ],
                              IconButton(
                                tooltip: 'Delete',
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () => _confirmDelete(record),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _header(String key) {
    if (key.toLowerCase() == 'box_id') return 'Box ID';
    if (key.toLowerCase() == 'vc_number') return 'VC Number';
    if (key.toLowerCase() == 'stb_id') return 'STB ID';
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  // ──────────────────────────── DELETE ────────────────────────────

  Future<void> _confirmDelete(AppRecord record) async {
    final name = record.text('name', record.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_outlined,
          color: Theme.of(ctx).colorScheme.error,
          size: 40,
        ),
        title: const Text('Delete record?'),
        content: Text(
          'Are you sure you want to delete "$name"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(repositoryProvider(widget.config.table)).delete(record.id);
      if (mounted) {
        ref.invalidate(moduleRowsProvider((widget.config, search)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" deleted')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $error')),
        );
      }
    }
  }

  // ──────────────────────────── EXPORT ────────────────────────────

  void _exportExcel(List<AppRecord> records) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Sheet1'];

    // Header row
    sheet.appendRow(
      widget.config.columns
          .map((c) => TextCellValue(_header(c)))
          .toList(),
    );

    // Data rows
    for (final record in records) {
      sheet.appendRow(
        widget.config.columns
            .map((c) => TextCellValue(record.text(c, '')))
            .toList(),
      );
    }

    final bytes = workbook.encode();
    if (bytes == null) return;
    final filename =
        '${widget.config.title.toLowerCase().replaceAll(' ', '_')}.xlsx';
    downloadBytes(bytes, filename);
  }

  // ──────────────────────────── IMPORT ────────────────────────────

  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file bytes.')),
        );
      }
      return;
    }

    // Parse the spreadsheet
    final excel = Excel.decodeBytes(file.bytes!);
    final sheetName = excel.tables.keys.firstOrNull;
    if (sheetName == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sheets found in the file.')),
        );
      }
      return;
    }

    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The spreadsheet is empty.')),
        );
      }
      return;
    }

    final importCols = widget.config.importColumns!;

    // First row = headers
    final headerRow = sheet.rows.first;
    final headers = headerRow
        .map((cell) => (cell?.value?.toString() ?? '').trim().toLowerCase())
        .toList();

    // Map each import column to its index in the spreadsheet
    final colIndexMap = <String, int>{};
    for (final col in importCols) {
      final header = col.toLowerCase();
      final idx = headers.indexOf(header);
      if (idx != -1) {
        colIndexMap[col] = idx;
      }
    }

    if (colIndexMap.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No matching columns found. Expected headers like: '
              '${importCols.join(", ")}',
            ),
          ),
        );
      }
      return;
    }

    // Build rows from data rows (skip header)
    final dataRows = sheet.rows.skip(1).where((row) {
      // Skip completely empty rows
      return row.any((cell) => cell?.value != null && '${cell!.value}'.trim().isNotEmpty);
    }).toList();

    if (dataRows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data rows found in the file.')),
        );
      }
      return;
    }

    // Show confirmation dialog
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.upload_file, size: 40),
        title: const Text('Import data?'),
        content: Text(
          'Found ${dataRows.length} row(s) in the spreadsheet.\n'
          'Matched columns: ${colIndexMap.keys.join(", ")}\n\n'
          'Do you want to import these records?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    // Perform the import
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Importing records...'),
              ],
            ),
          ),
        ),
      ),
    );

    int successCount = 0;
    int failCount = 0;

    final repo = ref.read(repositoryProvider(widget.config.table));

    for (final row in dataRows) {
      final payload = <String, dynamic>{};
      for (final entry in colIndexMap.entries) {
        final col = entry.key;
        final idx = entry.value;
        final value = idx < row.length
            ? (row[idx]?.value?.toString().trim() ?? '')
            : '';
        if (value.isNotEmpty) {
          payload[col] = value;
        }
      }
      // Skip rows with no data at all
      if (payload.isEmpty) continue;

      // Convert numeric fields
      for (final key in [
        'monthly_charge',
        'installation_charge',
        'security_deposit',
      ]) {
        if (payload.containsKey(key)) {
          payload[key] = num.tryParse('${payload[key]}') ?? 0;
        }
      }

      if (widget.config.table == 'customers' && !payload.containsKey('area_id')) {
        final currentUnit = ref.read(activeUnitIdProvider);
        if (currentUnit != null) {
          payload['area_id'] = currentUnit;
        }
      }

      try {
        await repo.upsert(payload);
        successCount++;
      } catch (e) {
        failCount++;
        if (kDebugMode) {
          debugPrint('Import row failed: $e — payload: $payload');
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop(); // dismiss loading
      ref.invalidate(moduleRowsProvider((widget.config, search)));
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            failCount == 0 ? Icons.check_circle_outline : Icons.warning_amber,
            color: failCount == 0
                ? Theme.of(ctx).colorScheme.primary
                : Theme.of(ctx).colorScheme.error,
            size: 40,
          ),
          title: const Text('Import complete'),
          content: Text(
            '$successCount record(s) imported successfully.'
            '${failCount > 0 ? '\n$failCount row(s) failed.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showCustomerDetails(AppRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _CustomerDetailsDialog(customer: record),
    );
  }
}

class _CustomerDetailsDialog extends StatefulWidget {
  const _CustomerDetailsDialog({required this.customer});
  final AppRecord customer;

  @override
  State<_CustomerDetailsDialog> createState() => _CustomerDetailsDialogState();
}

class _CustomerDetailsDialogState extends State<_CustomerDetailsDialog> {
  bool loading = true;
  num totalPaid = 0;
  num totalPending = 0;
  List<Map<String, dynamic>> payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final customerId = widget.customer.id;
      final paymentsRes = await supabase
          .from('payments')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      final billsRes = await supabase
          .from('monthly_bills')
          .select()
          .eq('customer_id', customerId)
          .neq('status', 'paid');

      final paymentRows = (paymentsRes as List).cast<Map<String, dynamic>>();
      final billRows = (billsRes as List).cast<Map<String, dynamic>>();

      final paidSum = paymentRows.fold<num>(
        0,
        (sum, p) => sum + (num.tryParse('${p['amount'] ?? 0}') ?? 0),
      );

      final pendingSum = billRows.fold<num>(
        0,
        (sum, b) =>
            sum +
            (num.tryParse('${b['total_amount'] ?? b['amount'] ?? 0}') ?? 0),
      );

      final monthlyCharge = widget.customer.number('monthly_charge');

      if (mounted) {
        setState(() {
          payments = paymentRows;
          totalPaid = paidSum;
          totalPending = pendingSum > 0
              ? pendingSum
              : (billRows.isEmpty ? 0 : monthlyCharge);
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final monthlyCharge = c.number('monthly_charge');

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.text('name'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(c.text('status')),
                  ],
                ),
                Text(
                  'Code: ${c.text("customer_code")} • Phone: ${c.text("phone")}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 520),
        child: loading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // ── Paid & Pending Financial Summary ──
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TOTAL PAID',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  money(totalPaid),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  '${payments.length} payment(s)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: totalPending > 0
                                  ? Colors.orange.withValues(alpha: 0.12)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: totalPending > 0
                                  ? Colors.orange.withValues(alpha: 0.4)
                                  : Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL PENDING',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: totalPending > 0
                                        ? Colors.orange.shade800
                                        : Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  money(totalPending),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: totalPending > 0
                                        ? Colors.orange.shade800
                                        : Colors.green,
                                  ),
                                ),
                                Text(
                                  totalPending > 0 ? 'Due to pay' : 'All cleared',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MONTHLY PLAN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  money(monthlyCharge),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const Text(
                                  'Per month',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Customer Hardware & Location Details ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inbox_outlined,
                                  size: 16, color: Colors.purple),
                              const SizedBox(width: 6),
                              const Text('Box ID: ',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                c.text('box_id'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.credit_card_outlined,
                                  size: 16, color: Colors.indigo),
                              const SizedBox(width: 6),
                              const Text('VC Number: ',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(c.text('vc_number')),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined,
                                  size: 16, color: Colors.teal),
                              const SizedBox(width: 6),
                              const Text('Alt Phone: '),
                              Text(c.text('alternate_number')),
                              const Spacer(),
                              const Icon(Icons.location_on_outlined,
                                  size: 16, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              const Text('Village: '),
                              Text(c.text('village')),
                            ],
                          ),
                          if (c.text('address') != '-') ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.home_outlined,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Address: ${c.text("address")}',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Payment History ──
                    Row(
                      children: [
                        const Text(
                          'Payment History',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${payments.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No payment records found yet.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: payments.length > 5 ? 5 : payments.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final p = payments[i];
                            final amount = num.tryParse('${p['amount'] ?? 0}') ?? 0;
                            final dateStr = p['created_at'] != null
                                ? DateFormat('dd MMM yyyy')
                                    .format(DateTime.parse('${p['created_at']}'))
                                : '-';
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${p['receipt_number'] ?? '-'}',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '$dateStr • ${(p['payment_method'] ?? 'cash').toString().toUpperCase()}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    money(amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.chat_bubble_outline,
              color: Colors.green, size: 18),
          label: const Text('WhatsApp'),
          onPressed: () {
            final phone = c.text('phone');
            final msg =
                '*CableCare Customer Summary*\n\n'
                'Dear ${c.text("name")},\n'
                'Here is your account statement:\n'
                '━━━━━━━━━━━━━━━━━━━━\n'
                '📦 Box ID: ${c.text("box_id")}\n'
                '💰 Total Paid: ${money(totalPaid)}\n'
                '⚖️ Remaining Due: ${totalPending > 0 ? money(totalPending) : "Nil (Cleared)"}\n'
                '━━━━━━━━━━━━━━━━━━━━\n\n'
                'Thank you for choosing CableCare!';
            NotificationService().openWhatsApp(phone: phone, message: msg);
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.sms_outlined, color: Colors.blue, size: 18),
          label: const Text('SMS'),
          onPressed: () {
            final phone = c.text('phone');
            final msg =
                'Dear ${c.text("name")}, Box ID: ${c.text("box_id")}, '
                'Total Paid: ${money(totalPaid)}, Pending Due: ${money(totalPending)}. '
                'Thank you - CableCare.';
            NotificationService().openSMS(phone: phone, message: msg);
          },
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Public provider — expose so form pages can call ref.invalidate(moduleRowsProvider)
/// after a successful save to force the list to re-fetch fresh data.
final moduleRowsProvider =
    FutureProvider.family<List<AppRecord>, (ModuleConfig, String)>((ref, args) {
      final (config, search) = args;
      final activeUnitId = ref.watch(activeUnitIdProvider);
      final filters = <String, Object?>{};
      if (activeUnitId != null &&
          (config.table == 'customers' || config.table == 'complaints')) {
        filters['area_id'] = activeUnitId;
      }
      return ref
          .read(repositoryProvider(config.table))
          .list(
            search: search,
            searchColumns: config.searchColumns,
            filters: filters,
          );
    });
