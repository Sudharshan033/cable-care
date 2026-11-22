import 'package:cableapp/core/services/unit_service.dart';
import 'package:cableapp/core/utils/file_download.dart';
import 'package:cableapp/core/utils/formatters.dart';
import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/data/models/app_record.dart';
import 'package:cableapp/data/repositories/base_repository.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';

final _expensesProvider = FutureProvider<List<AppRecord>>((ref) {
  final activeUnit = ref.watch(unitProvider).activeUnit;
  final records = ref.watch(repositoryProvider('expenses')).list(limit: 500);
  if (activeUnit == null) return records;
  return records.then((list) => list.where((r) {
    final notes = r.text('notes');
    return notes.contains('[${activeUnit.name}]') || !notes.contains('[');
  }).toList());
});

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  String search = '';
  String selectedCategory = 'all';

  static const categories = [
    'electricity',
    'fuel',
    'salary',
    'equipment',
    'cable_purchase',
    'maintenance',
    'office_rent',
    'miscellaneous',
  ];

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(_expensesProvider);

    return ListView(
      children: [
        PageHeader(
          title: 'Expenses',
          subtitle: 'Track operational costs, hardware purchases, salaries, and maintenance.',
          actions: [
            FilledButton.icon(
              onPressed: () => _showAddExpenseDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary Card & Filters
        expensesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (records) {
            final totalAmount = records.fold<num>(
              0,
              (sum, item) => sum + item.number('amount'),
            );
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Expenses Recorded',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          money(totalAmount),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${records.length} records',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
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
                  width: 260,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search paid to or notes...',
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
                    _categoryChip('all', 'All'),
                    _categoryChip('fuel', 'Fuel'),
                    _categoryChip('salary', 'Salary'),
                    _categoryChip('cable_purchase', 'Cable Wire'),
                    _categoryChip('equipment', 'Equipment'),
                    _categoryChip('maintenance', 'Maintenance'),
                    _categoryChip('electricity', 'Electricity'),
                  ],
                ),
                const Spacer(),
                expensesAsync.whenOrNull(
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

        // Expense Table
        expensesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error loading expenses: $e')),
          data: (records) {
            var filtered = records;
            if (selectedCategory != 'all') {
              filtered = filtered
                  .where((r) =>
                      r.text('category').toLowerCase() == selectedCategory)
                  .toList();
            }
            if (search.isNotEmpty) {
              filtered = filtered.where((r) {
                final q = search.toLowerCase();
                return r.text('paid_to').toLowerCase().contains(q) ||
                    r.text('notes').toLowerCase().contains(q) ||
                    r.text('category').toLowerCase().contains(q);
              }).toList();
            }

            if (filtered.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No expense records found.'),
                ),
              );
            }

            return Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Paid To')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('Notes')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: filtered
                      .map(
                        (r) => DataRow(cells: [
                          DataCell(Text(_fmtDate(r.text('expense_date')))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                labelize(r.text('category')),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              money(r.number('amount')),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                          DataCell(Text(r.text('paid_to'))),
                          DataCell(Text(r.text('payment_method').toUpperCase())),
                          DataCell(
                            SizedBox(
                              width: 160,
                              child: Text(
                                r.text('notes'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 20),
                              tooltip: 'Delete',
                              onPressed: () => _confirmDelete(r),
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

  Widget _categoryChip(String key, String label) {
    final selected = selectedCategory == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => selectedCategory = key),
    );
  }

  Future<void> _showAddExpenseDialog(BuildContext context) async {
    final formKey = GlobalKey<FormBuilderState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_card_outlined, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Record New Expense'),
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
                  FormBuilderDropdown<String>(
                    name: 'category',
                    initialValue: 'fuel',
                    decoration: const InputDecoration(
                      labelText: 'Expense Category *',
                      border: OutlineInputBorder(),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(labelize(c)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'amount',
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹) *',
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.numeric(),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'paid_to',
                    decoration: const InputDecoration(
                      labelText: 'Paid To (Person / Vendor) *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: FormBuilderValidators.required(),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderDropdown<String>(
                    name: 'payment_method',
                    initialValue: 'cash',
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      'cash',
                      'upi',
                      'bank_transfer',
                      'cheque',
                    ]
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.toUpperCase()),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderDateTimePicker(
                    name: 'expense_date',
                    inputType: InputType.date,
                    initialValue: DateTime.now(),
                    format: DateFormat('yyyy-MM-dd'),
                    decoration: const InputDecoration(
                      labelText: 'Expense Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'notes',
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks',
                      border: OutlineInputBorder(),
                    ),
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
              values['amount'] =
                  num.tryParse('${values['amount'] ?? 0}') ?? 0;
              final dt = values['expense_date'] as DateTime?;
              if (dt != null) {
                values['expense_date'] = DateFormat('yyyy-MM-dd').format(dt);
              }
              final activeUnit = ref.read(unitProvider).activeUnit;
              final existingNotes = values['notes']?.toString().trim() ?? '';
              if (activeUnit != null) {
                values['notes'] = existingNotes.isEmpty
                    ? '[${activeUnit.name}]'
                    : '[${activeUnit.name}] $existingNotes';
              }

              try {
                await ref
                    .read(repositoryProvider('expenses'))
                    .upsert(values);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ref.invalidate(_expensesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Expense recorded successfully!')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to save expense: $e')),
                  );
                }
              }
            },
            child: const Text('Save Expense'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(AppRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 40),
        title: const Text('Delete Expense?'),
        content: Text(
          'Delete expense of ${money(record.number("amount"))} paid to "${record.text("paid_to")}"?',
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
      await ref.read(repositoryProvider('expenses')).delete(record.id);
      ref.invalidate(_expensesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted')),
        );
      }
    }
  }

  void _exportExcel(List<AppRecord> records) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Expenses'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Paid To'),
      TextCellValue('Payment Method'),
      TextCellValue('Notes'),
    ]);
    for (final r in records) {
      sheet.appendRow([
        TextCellValue(_fmtDate(r.text('expense_date'))),
        TextCellValue(r.text('category')),
        TextCellValue(r.number('amount').toString()),
        TextCellValue(r.text('paid_to')),
        TextCellValue(r.text('payment_method')),
        TextCellValue(r.text('notes')),
      ]);
    }
    final bytes = workbook.encode();
    if (bytes == null) return;
    downloadBytes(bytes, 'expenses.xlsx');
  }

  String _fmtDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return shortDate(dt);
  }
}
