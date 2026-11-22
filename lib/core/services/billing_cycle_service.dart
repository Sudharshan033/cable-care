import 'package:cableapp/data/supabase_client.dart';

class BillingCycleService {
  /// Ensures that all active customers have a bill for the current month in 'pending' status.
  /// If an active customer did not pay last month, the previous unpaid balance
  /// automatically rolls over into 'previous_due'.
  static Future<void> ensureMonthlyBills() async {
    try {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      final customersRes = await supabase
          .from('customers')
          .select('id, name, monthly_charge')
          .eq('status', 'active');

      final customers = (customersRes as List).cast<Map<String, dynamic>>();

      for (final c in customers) {
        final custId = '${c['id']}';
        final monthlyCharge = num.tryParse('${c['monthly_charge'] ?? 0}') ?? 0;

        final existing = await supabase
            .from('monthly_bills')
            .select('id')
            .eq('customer_id', custId)
            .eq('bill_month', currentMonth)
            .eq('bill_year', currentYear)
            .maybeSingle();

        if (existing == null) {
          // Calculate any unpaid dues from past months
          final pastUnpaidRes = await supabase
              .from('monthly_bills')
              .select('total_amount, amount')
              .eq('customer_id', custId)
              .neq('status', 'paid');

          final pastUnpaid =
              (pastUnpaidRes as List).cast<Map<String, dynamic>>();

          final prevDue = pastUnpaid.fold<num>(
            0,
            (sum, row) =>
                sum +
                (num.tryParse('${row['total_amount'] ?? row['amount'] ?? 0}') ??
                    0),
          );

          await supabase.from('monthly_bills').insert({
            'customer_id': custId,
            'bill_month': currentMonth,
            'bill_year': currentYear,
            'amount': monthlyCharge,
            'previous_due': prevDue,
            'status': 'pending',
          });
        }
      }
    } catch (_) {
      // Background sync safe guard
    }
  }

  /// Mark the customer's current bill as paid or partial
  static Future<void> updateCurrentBillStatus({
    required String customerId,
    required String status, // 'paid', 'partial', 'pending'
  }) async {
    try {
      final now = DateTime.now();
      await supabase
          .from('monthly_bills')
          .update({'status': status})
          .eq('customer_id', customerId)
          .eq('bill_month', now.month)
          .eq('bill_year', now.year);
    } catch (_) {}
  }
}

