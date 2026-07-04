import 'package:cableapp/core/utils/file_download.dart';
import 'package:cableapp/core/utils/formatters.dart';
import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/data/models/app_record.dart';
import 'package:cableapp/data/repositories/base_repository.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

final _paymentHistoryProvider = FutureProvider<List<AppRecord>>((ref) {
  return ref.read(repositoryProvider('payments')).list(limit: 500);
});

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  final formKey = GlobalKey<FormBuilderState>();
  bool saving = false;
  AppRecord? _selectedCustomer;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(_paymentHistoryProvider);
    return ListView(
      children: [
        const PageHeader(
          title: 'Payments',
          subtitle: 'Record payments and export payment history.',
        ),
        const SizedBox(height: 16),

        // ── Record payment form ─────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer search
                Autocomplete<AppRecord>(
                  displayStringForOption: (r) =>
                      '${r.text('name')} — ${r.text('phone')}',
                  optionsBuilder: (textEditingValue) async {
                    final q = textEditingValue.text.trim();
                    if (q.length < 2) return [];
                    return ref
                        .read(repositoryProvider('customers'))
                        .list(
                          search: q,
                          searchColumns: ['name', 'phone'],
                          limit: 8,
                        );
                  },
                  onSelected: (c) => setState(() => _selectedCustomer = c),
                  fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    decoration: InputDecoration(
                      labelText: 'Search customer by name or phone',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ),
                if (_selectedCustomer != null) ...
                  [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color:
                                  Theme.of(context).colorScheme.primary,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _selectedCustomer!.text('name'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.phone_outlined, size: 15,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(_selectedCustomer!.text('phone')),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedCustomer = null),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  ],
                const Divider(height: 28),
                FormBuilder(
                  key: formKey,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _field('amount', 'Amount', required: true, number: true),
                      SizedBox(
                        width: 300,
                        child: FormBuilderDropdown<String>(
                          name: 'payment_method',
                          initialValue: 'cash',
                          decoration: const InputDecoration(
                            labelText: 'Payment method',
                          ),
                          items: const [
                            'cash',
                            'upi',
                            'bank_transfer',
                            'cheque',
                          ]
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(v),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      SizedBox(
                        width: 620,
                        child: FilledButton.icon(
                          onPressed: saving ? null : _save,
                          icon: saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.receipt_long_outlined),
                          label: const Text('Record payment'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Payment history ─────────────────────────────────────────────
        Row(
          children: [
            Text(
              'Payment History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            historyAsync.whenOrNull(
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
        const SizedBox(height: 8),
        historyAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load history: $e'),
          data: (records) {
            if (records.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No payments recorded yet.'),
                ),
              );
            }
            return Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Receipt #')),
                    DataColumn(label: Text('Customer ID')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('Date')),
                  ],
                  rows: records
                      .map(
                        (r) => DataRow(cells: [
                          DataCell(Text(r.text('receipt_number'))),
                          DataCell(Text(r.text('customer_id'))),
                          DataCell(Text(money(r.number('amount')))),
                          DataCell(Text(r.text('payment_method'))),
                          DataCell(
                              Text(_fmtDate(r.text('created_at')))),
                        ]),
                      )
                      .toList(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _field(
    String name,
    String label, {
    bool required = false,
    bool number = false,
    double width = 300,
  }) {
    return SizedBox(
      width: width,
      child: FormBuilderTextField(
        name: name,
        decoration: InputDecoration(labelText: label),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        validator: required ? FormBuilderValidators.required() : null,
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first')),
      );
      return;
    }
    if (!(formKey.currentState?.saveAndValidate() ?? false)) return;
    setState(() => saving = true);
    final values = Map<String, dynamic>.from(formKey.currentState!.value);
    values['amount'] = num.tryParse('${values['amount'] ?? 0}') ?? 0;
    values['customer_id'] = _selectedCustomer!.id;
    try {
      await ref.read(repositoryProvider('payments')).upsert(values);
      await ref.read(repositoryProvider('payment_history')).upsert({
        'customer_id': _selectedCustomer!.id,
        'amount': values['amount'],
        'payment_method': values['payment_method'] ?? 'cash',
      });
      if (mounted) {
        formKey.currentState?.reset();
        setState(() => _selectedCustomer = null);
        ref.invalidate(_paymentHistoryProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _exportExcel(List<AppRecord> records) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Payments'];
    sheet.appendRow([
      TextCellValue('Receipt #'),
      TextCellValue('Customer ID'),
      TextCellValue('Amount'),
      TextCellValue('Payment Method'),
      TextCellValue('Date'),
    ]);
    for (final r in records) {
      sheet.appendRow([
        TextCellValue(r.text('receipt_number')),
        TextCellValue(r.text('customer_id')),
        TextCellValue(r.number('amount').toString()),
        TextCellValue(r.text('payment_method')),
        TextCellValue(_fmtDate(r.text('created_at'))),
      ]);
    }
    final bytes = workbook.encode();
    if (bytes == null) return;
    downloadBytes(bytes, 'payments.xlsx');
  }

  String _fmtDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return shortDate(dt);
  }
}

