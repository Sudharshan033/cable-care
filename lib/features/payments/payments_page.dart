import 'package:cableapp/core/services/billing_cycle_service.dart';
import 'package:cableapp/core/services/unit_service.dart';
import 'package:cableapp/core/utils/file_download.dart';
import 'package:cableapp/core/utils/formatters.dart';
import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/core/widgets/status_badge.dart';
import 'package:cableapp/data/models/app_record.dart';
import 'package:cableapp/data/repositories/base_repository.dart';
import 'package:cableapp/data/supabase_client.dart';
import 'package:cableapp/features/notifications/notification_service.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

final _paymentHistoryProvider = FutureProvider<List<AppRecord>>((ref) async {
  final activeUnit = ref.watch(activeUnitIdProvider);
  final response = await supabase
      .from('payments')
      .select('*, customers(name, phone, box_id, customer_code, village, area_id)')
      .order('created_at', ascending: false)
      .limit(500);
  final list = (response as List).cast<Map<String, dynamic>>();
  final filtered = activeUnit == null
      ? list
      : list.where((p) => p['customers']?['area_id'] == activeUnit).toList();
  return filtered.map(AppRecord.new).toList();
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
  String _paymentStatus = 'paid'; // 'paid', 'partial', 'pending'
  String _historyFilter = 'all'; // 'all', 'paid', 'partial', 'pending'
  num _enteredAmount = 0;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(_paymentHistoryProvider);
    final monthlyCharge = _selectedCustomer?.number('monthly_charge') ?? 0;
    final remainingPending = (_paymentStatus == 'pending')
        ? monthlyCharge
        : (monthlyCharge - _enteredAmount).clamp(0, double.infinity);

    return ListView(
      children: [
        const PageHeader(
          title: 'Payments',
          subtitle: 'Record payments, manage pending/partial dues, and export history.',
        ),
        const SizedBox(height: 16),

        // ── Record payment form ─────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer search (by name, phone, box_id, customer_code)
                Autocomplete<AppRecord>(
                  displayStringForOption: (r) {
                    final box = r.text('box_id');
                    final boxStr = (box != '-' && box.isNotEmpty) ? ' • Box: $box' : '';
                    return '${r.text('name')} — ${r.text('phone')}$boxStr';
                  },
                  optionsBuilder: (textEditingValue) async {
                    final q = textEditingValue.text.trim();
                    if (q.length < 2) return [];
                    final activeUnit = ref.read(activeUnitIdProvider);
                    final filters = <String, Object?>{};
                    if (activeUnit != null) {
                      filters['area_id'] = activeUnit;
                    }
                    return ref
                        .read(repositoryProvider('customers'))
                        .list(
                          search: q,
                          searchColumns: [
                            'name',
                            'phone',
                            'box_id',
                            'vc_number',
                            'customer_code',
                            'village',
                          ],
                          filters: filters,
                          limit: 10,
                        );
                  },
                  onSelected: (c) {
                    final monthly = c.number('monthly_charge');
                    setState(() {
                      _selectedCustomer = c;
                      _paymentStatus = 'paid';
                      _enteredAmount = monthly;
                    });
                    formKey.currentState?.fields['payment_status']?.didChange('paid');
                    formKey.currentState?.fields['amount']?.didChange(monthly.toString());
                  },
                  fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    decoration: InputDecoration(
                      labelText: 'Search customer by name, phone, or Box ID',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ),
                if (_selectedCustomer != null) ...[
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
                        const SizedBox(width: 14),
                        Icon(Icons.phone_outlined,
                            size: 15,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(_selectedCustomer!.text('phone')),
                        if (_selectedCustomer!.text('box_id') != '-') ...[
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inbox_outlined,
                                    size: 14, color: Colors.purple),
                                const SizedBox(width: 4),
                                Text(
                                  'Box: ${_selectedCustomer!.text("box_id")}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Monthly: ${money(monthlyCharge)}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCustomer = null;
                              _enteredAmount = 0;
                            });
                            formKey.currentState?.reset();
                          },
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
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 1. Payment Status: Paid, Partially Paid, Pending
                      SizedBox(
                        width: 280,
                        child: FormBuilderDropdown<String>(
                          name: 'payment_status',
                          initialValue: _paymentStatus,
                          decoration: const InputDecoration(
                            labelText: 'Payment Status',
                            prefixIcon: Icon(Icons.rule_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'paid',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 18),
                                  SizedBox(width: 8),
                                  Text('Paid (Full Payment)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'partial',
                              child: Row(
                                children: [
                                  Icon(Icons.pie_chart,
                                      color: Colors.amber, size: 18),
                                  SizedBox(width: 8),
                                  Text('Partially Paid'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'pending',
                              child: Row(
                                children: [
                                  Icon(Icons.pending_actions,
                                      color: Colors.orange, size: 18),
                                  SizedBox(width: 8),
                                  Text('Pending (Unpaid)'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _paymentStatus = val);
                            if (val == 'paid') {
                              _enteredAmount = monthlyCharge;
                              formKey.currentState?.fields['amount']
                                  ?.didChange(monthlyCharge.toString());
                            } else if (val == 'pending') {
                              _enteredAmount = 0;
                              formKey.currentState?.fields['amount']
                                  ?.didChange('0');
                            }
                          },
                        ),
                      ),

                      // 2. Amount field
                      SizedBox(
                        width: 240,
                        child: FormBuilderTextField(
                          name: 'amount',
                          enabled: _paymentStatus != 'pending',
                          decoration: InputDecoration(
                            labelText: _paymentStatus == 'pending'
                                ? 'Amount (₹0 for Pending)'
                                : 'Amount',
                            prefixIcon: const Icon(Icons.currency_rupee),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _paymentStatus == 'pending'
                              ? null
                              : FormBuilderValidators.compose([
                                  FormBuilderValidators.required(),
                                  FormBuilderValidators.numeric(),
                                ]),
                          onChanged: (val) {
                            setState(() {
                              _enteredAmount =
                                  num.tryParse(val ?? '0') ?? 0;
                            });
                          },
                        ),
                      ),

                      // 3. Payment Method
                      SizedBox(
                        width: 220,
                        child: FormBuilderDropdown<String>(
                          name: 'payment_method',
                          initialValue: 'cash',
                          enabled: _paymentStatus != 'pending',
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
                                  child: Text(v.toUpperCase()),
                                ),
                              )
                              .toList(),
                        ),
                      ),

                      // 4. Live Pending indicator summary
                      if (_selectedCustomer != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _paymentStatus == 'paid'
                                ? Colors.green.withValues(alpha: 0.08)
                                : _paymentStatus == 'partial'
                                    ? Colors.amber.withValues(alpha: 0.12)
                                    : Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _paymentStatus == 'paid'
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : _paymentStatus == 'partial'
                                      ? Colors.amber.withValues(alpha: 0.4)
                                      : Colors.orange.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Total Due: ${money(monthlyCharge)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 20),
                              Text(
                                'Amount Paid: ${money(_paymentStatus == "pending" ? 0 : _enteredAmount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _paymentStatus == 'pending'
                                      ? Colors.grey
                                      : Colors.green,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Remaining Pending: ${money(remainingPending)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: remainingPending > 0
                                      ? Colors.orange.shade800
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 5. Submit Button
                      SizedBox(
                        width: double.infinity,
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
                              : Icon(_paymentStatus == 'pending'
                                  ? Icons.pending_actions
                                  : Icons.receipt_long_outlined),
                          label: Text(
                            _paymentStatus == 'pending'
                                ? 'Record as Pending (${money(monthlyCharge)})'
                                : _paymentStatus == 'partial'
                                    ? 'Record Partial Payment (${money(_enteredAmount)})'
                                    : 'Record Full Payment (${money(_enteredAmount)})',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: _paymentStatus == 'pending'
                                ? Colors.orange.shade800
                                : _paymentStatus == 'partial'
                                    ? Colors.amber.shade900
                                    : null,
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

        // ── Payment history with Status Filter ───────────────────────────
        Row(
          children: [
            Text(
              'Payment History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 16),
            // Filter chips
            Wrap(
              spacing: 6,
              children: [
                _filterChip('all', 'All'),
                _filterChip('paid', 'Paid'),
                _filterChip('partial', 'Partially Paid'),
                _filterChip('pending', 'Pending'),
              ],
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
            final filtered = _historyFilter == 'all'
                ? records
                : records.where((r) {
                    final st = r.text('notes', 'paid').toLowerCase();
                    return st == _historyFilter;
                  }).toList();

            if (filtered.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No payments found for this filter.'),
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
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('Date')),
                  ],
                  rows: filtered
                      .map(
                        (r) => DataRow(cells: [
                          DataCell(Text(r.text('receipt_number'))),
                          DataCell(Text(r.text('customer_id'))),
                          DataCell(Text(money(r.number('amount')))),
                          DataCell(StatusBadge(r.text('notes', 'paid'))),
                          DataCell(Text(r.text('payment_method').toUpperCase())),
                          DataCell(Text(_fmtDate(r.text('created_at')))),
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

  Widget _filterChip(String key, String label) {
    final selected = _historyFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _historyFilter = key),
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
    final customer = _selectedCustomer!;
    final values = Map<String, dynamic>.from(formKey.currentState!.value);
    final paidAmount = _paymentStatus == 'pending'
        ? 0
        : (num.tryParse('${values['amount'] ?? 0}') ?? 0);
    values['amount'] = paidAmount;
    values['customer_id'] = customer.id;
    final receiptNumber = 'RCPT-${DateTime.now().millisecondsSinceEpoch}';
    values['receipt_number'] = receiptNumber;
    values['notes'] = _paymentStatus; // Storing status in notes
    values['payment_method'] = _paymentStatus == 'pending' ? 'due' : (values['payment_method'] ?? 'cash');

    final monthlyCharge = customer.number('monthly_charge');
    final remainingPending = (_paymentStatus == 'pending')
        ? monthlyCharge
        : (monthlyCharge - paidAmount).clamp(0, double.infinity);

    try {
      await ref.read(repositoryProvider('payments')).upsert(values);
      await ref.read(repositoryProvider('payment_history')).upsert({
        'customer_id': customer.id,
        'amount': paidAmount,
        'payment_method': values['payment_method'],
      });
      // Automatically update monthly bill status in monthly_bills
      await BillingCycleService.updateCurrentBillStatus(
        customerId: customer.id,
        status: _paymentStatus,
      );
      if (mounted) {
        formKey.currentState?.reset();
        setState(() {
          _selectedCustomer = null;
          _enteredAmount = 0;
          _paymentStatus = 'paid';
        });
        ref.invalidate(_paymentHistoryProvider);

        final customerName = customer.text('name');
        final phone = customer.text('phone');
        final paymentMethod = values['payment_method'];

        // Tailor message based on status
        final String whatsappMsg;
        final String smsMsg;

        if (_paymentStatus == 'pending') {
          whatsappMsg =
              '*CableCare Payment Reminder*\n\n'
              'Dear $customerName,\n'
              'This is a notification that your cable TV bill is marked as *Pending*.\n\n'
              '━━━━━━━━━━━━━━━━━━━━\n'
              '📄 Reference No: $receiptNumber\n'
              '💰 Pending Due: ${money(monthlyCharge)}\n'
              '━━━━━━━━━━━━━━━━━━━━\n\n'
              'Please make the payment at the earliest to ensure uninterrupted service.\n'
              'Thank you - CableCare!';

          smsMsg =
              'Dear $customerName, your CableCare bill of ${money(monthlyCharge)} is marked as PENDING. '
              'Please pay soon to avoid disconnection. Thank you.';
        } else {
          final isPartial = _paymentStatus == 'partial';
          whatsappMsg =
              '*CableCare Payment Receipt*\n\n'
              'Dear $customerName,\n'
              'Thank you! Your ${isPartial ? "partial " : ""}payment has been received.\n\n'
              '━━━━━━━━━━━━━━━━━━━━\n'
              '📄 Receipt No: $receiptNumber\n'
              '💰 Amount Paid: ${money(paidAmount)} ($paymentMethod)\n'
              '⚖️ Remaining Pending: ${remainingPending > 0 ? money(remainingPending) : "Nil (Fully Paid)"}\n'
              '━━━━━━━━━━━━━━━━━━━━\n\n'
              'Thank you for choosing CableCare!';

          smsMsg =
              'Dear $customerName, your ${isPartial ? "partial " : ""}payment of ${money(paidAmount)} is received. '
              'Rcpt: $receiptNumber. Remaining Due: ${remainingPending > 0 ? money(remainingPending) : "NIL"}. '
              'Thank you - CableCare.';
        }

        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              _paymentStatus == 'pending'
                  ? Icons.pending_actions
                  : Icons.check_circle_outline,
              color: _paymentStatus == 'pending'
                  ? Colors.orange
                  : _paymentStatus == 'partial'
                      ? Colors.amber.shade800
                      : Colors.green,
              size: 48,
            ),
            title: Text(
              _paymentStatus == 'pending'
                  ? 'Marked as Pending'
                  : _paymentStatus == 'partial'
                      ? 'Partial Payment Recorded'
                      : 'Payment Recorded',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: $customerName'),
                Text('Phone: $phone'),
                Text('Receipt: $receiptNumber'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('Status: '),
                    StatusBadge(_paymentStatus),
                  ],
                ),
                const Divider(),
                Text(
                  'Amount Paid: ${money(paidAmount)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
                Text(
                  'Remaining Pending: ${remainingPending > 0 ? money(remainingPending) : "₹0 (Cleared)"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: remainingPending > 0
                        ? Colors.orange.shade800
                        : Colors.green,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                label: const Text('WhatsApp'),
                onPressed: () {
                  NotificationService().openWhatsApp(phone: phone, message: whatsappMsg);
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.sms_outlined, color: Colors.blue),
                label: const Text('SMS'),
                onPressed: () {
                  NotificationService().openSMS(phone: phone, message: smsMsg);
                },
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $error')),
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
      TextCellValue('Status'),
      TextCellValue('Payment Method'),
      TextCellValue('Date'),
    ]);
    for (final r in records) {
      sheet.appendRow([
        TextCellValue(r.text('receipt_number')),
        TextCellValue(r.text('customer_id')),
        TextCellValue(r.number('amount').toString()),
        TextCellValue(r.text('notes', 'paid')),
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
