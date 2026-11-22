import 'package:cableapp/core/services/unit_service.dart';
import 'package:cableapp/core/utils/file_download.dart';
import 'package:cableapp/core/utils/formatters.dart';
import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/core/widgets/status_badge.dart';
import 'package:cableapp/data/models/app_record.dart';
import 'package:cableapp/data/repositories/base_repository.dart';
import 'package:cableapp/features/notifications/notification_service.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

final _complaintsProvider = FutureProvider<List<AppRecord>>((ref) {
  final activeUnit = ref.watch(activeUnitIdProvider);
  final filters = <String, Object?>{};
  if (activeUnit != null) {
    filters['area_id'] = activeUnit;
  }
  return ref.read(repositoryProvider('complaints')).list(limit: 500, filters: filters);
});

class ComplaintsPage extends ConsumerStatefulWidget {
  const ComplaintsPage({super.key});

  @override
  ConsumerState<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends ConsumerState<ComplaintsPage> {
  String search = '';
  String selectedStatus = 'all';

  static const types = [
    'no_signal',
    'wire_cut',
    'remote_issue',
    'box_issue',
    'low_quality',
    'subscription',
    'other',
  ];

  static const priorities = [
    'low',
    'medium',
    'high',
    'urgent',
  ];

  static const statuses = [
    'open',
    'in_progress',
    'completed',
    'closed',
  ];

  @override
  Widget build(BuildContext context) {
    final complaintsAsync = ref.watch(_complaintsProvider);

    return ListView(
      children: [
        PageHeader(
          title: 'Complaints',
          subtitle: 'Log, track, assign, and resolve customer issues and service requests.',
          actions: [
            FilledButton.icon(
              onPressed: () => _showAddComplaintDialog(context),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Add Complaint'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary metric cards
        complaintsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (records) {
            final openCount = records
                .where((r) => r.text('status').toLowerCase() == 'open')
                .length;
            final inProgressCount = records
                .where((r) => r.text('status').toLowerCase() == 'in_progress')
                .length;
            final completedCount = records
                .where((r) =>
                    r.text('status').toLowerCase() == 'completed' ||
                    r.text('status').toLowerCase() == 'closed')
                .length;

            return Row(
              children: [
                Expanded(
                  child: _metricCard(
                    title: 'Open Complaints',
                    value: '$openCount',
                    color: Colors.red,
                    icon: Icons.error_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    title: 'In Progress',
                    value: '$inProgressCount',
                    color: Colors.orange,
                    icon: Icons.pending_actions_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    title: 'Resolved / Closed',
                    value: '$completedCount',
                    color: Colors.green,
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // Search & Filter & Export Bar
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search number, phone, or description...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) => setState(() => search = val.trim()),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    _statusChip('all', 'All'),
                    _statusChip('open', 'Open'),
                    _statusChip('in_progress', 'In Progress'),
                    _statusChip('completed', 'Completed'),
                    _statusChip('closed', 'Closed'),
                  ],
                ),
                const Spacer(),
                complaintsAsync.whenOrNull(
                      data: (records) => OutlinedButton.icon(
                        onPressed:
                            records.isEmpty ? null : () => _exportExcel(records),
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

        // Complaints Table
        complaintsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error loading complaints: $e')),
          data: (records) {
            var filtered = records;
            if (selectedStatus != 'all') {
              filtered = filtered
                  .where((r) =>
                      r.text('status').toLowerCase() == selectedStatus)
                  .toList();
            }
            if (search.isNotEmpty) {
              filtered = filtered.where((r) {
                final q = search.toLowerCase();
                return r.text('complaint_number').toLowerCase().contains(q) ||
                    r.text('phone').toLowerCase().contains(q) ||
                    r.text('description').toLowerCase().contains(q) ||
                    r.text('complaint_type').toLowerCase().contains(q);
              }).toList();
            }

            if (filtered.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No complaints found.'),
                ),
              );
            }

            return Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Complaint #')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Priority')),
                    DataColumn(label: Text('Status (Tap to Change)')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: filtered
                      .map(
                        (r) => DataRow(cells: [
                          DataCell(
                            Text(
                              r.text('complaint_number'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataCell(Text(r.text('phone'))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                labelize(r.text('complaint_type')),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(_priorityChip(r.text('priority'))),
                          DataCell(
                            InkWell(
                              onTap: () => _showChangeStatusDialog(r),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusBadge(r.text('status')),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down,
                                        size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Text(
                                r.text('description'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline,
                                      color: Colors.green, size: 20),
                                  tooltip: 'WhatsApp Customer',
                                  onPressed: () {
                                    final phone = r.text('phone');
                                    final cmp = r.text('complaint_number');
                                    final st = r.text('status').toUpperCase();
                                    final msg =
                                        'Hello, this is CableCare regarding your complaint $cmp. '
                                        'Current status is: $st. '
                                        'We are working to resolve it at the earliest.';
                                    NotificationService()
                                        .openWhatsApp(phone: phone, message: msg);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  tooltip: 'Delete',
                                  onPressed: () => _confirmDelete(r),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      )
                      .toList(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityChip(String priority) {
    final color = switch (priority.toLowerCase()) {
      'urgent' => Colors.red,
      'high' => Colors.deepOrange,
      'medium' => Colors.amber.shade800,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        labelize(priority),
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _statusChip(String key, String label) {
    final selected = selectedStatus == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => selectedStatus = key),
    );
  }

  Future<void> _showAddComplaintDialog(BuildContext context) async {
    final formKey = GlobalKey<FormBuilderState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.report_problem_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Register Customer Complaint'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: FormBuilder(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FormBuilderTextField(
                    name: 'phone',
                    decoration: const InputDecoration(
                      labelText: 'Customer Phone *',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: FormBuilderValidators.required(),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderDropdown<String>(
                    name: 'complaint_type',
                    initialValue: 'no_signal',
                    decoration: const InputDecoration(
                      labelText: 'Complaint Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: types
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(labelize(t)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderDropdown<String>(
                    name: 'priority',
                    initialValue: 'medium',
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: priorities
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(labelize(p)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'description',
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Complaint Description *',
                      hintText: 'e.g. Wire cut near post 12, TV showing no signal',
                      border: OutlineInputBorder(),
                    ),
                    validator: FormBuilderValidators.required(),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.saveAndValidate() ?? false)) return;
              final values =
                  Map<String, dynamic>.from(formKey.currentState!.value);
              values['status'] = 'open';
              final currentUnit = ref.read(activeUnitIdProvider);
              if (currentUnit != null) {
                values['area_id'] = currentUnit;
              }

              try {
                await ref
                    .read(repositoryProvider('complaints'))
                    .upsert(values);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ref.invalidate(_complaintsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Complaint registered successfully!')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to register complaint: $e')),
                  );
                }
              }
            },
            child: const Text('Register Complaint'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangeStatusDialog(AppRecord record) async {
    final currentStatus = record.text('status', 'open').toLowerCase();

    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Update Status: ${record.text("complaint_number")}'),
        children: statuses.map((st) {
          final isSelected = st == currentStatus;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (st != currentStatus) {
                try {
                  await ref.read(repositoryProvider('complaints')).update(
                    record.id,
                    {
                      'status': st,
                      if (st == 'completed' || st == 'closed')
                        'completed_at': DateTime.now().toIso8601String(),
                    },
                  );
                  ref.invalidate(_complaintsProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Complaint ${record.text("complaint_number")} updated to ${labelize(st)}',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update status: $e')),
                    );
                  }
                }
              }
            },
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.green : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 10),
                StatusBadge(st),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _confirmDelete(AppRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 40),
        title: const Text('Delete Complaint?'),
        content: Text(
          'Delete complaint ${record.text("complaint_number")} for ${record.text("phone")}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(repositoryProvider('complaints')).delete(record.id);
      ref.invalidate(_complaintsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint deleted')),
        );
      }
    }
  }

  void _exportExcel(List<AppRecord> records) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Complaints'];
    sheet.appendRow([
      TextCellValue('Complaint #'),
      TextCellValue('Phone'),
      TextCellValue('Type'),
      TextCellValue('Priority'),
      TextCellValue('Status'),
      TextCellValue('Description'),
      TextCellValue('Date'),
    ]);
    for (final r in records) {
      sheet.appendRow([
        TextCellValue(r.text('complaint_number')),
        TextCellValue(r.text('phone')),
        TextCellValue(r.text('complaint_type')),
        TextCellValue(r.text('priority')),
        TextCellValue(r.text('status')),
        TextCellValue(r.text('description')),
        TextCellValue(_fmtDate(r.text('created_at'))),
      ]);
    }
    final bytes = workbook.encode();
    if (bytes == null) return;
    downloadBytes(bytes, 'complaints.xlsx');
  }

  String _fmtDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return shortDate(dt);
  }
}
