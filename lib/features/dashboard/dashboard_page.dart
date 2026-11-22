import 'package:cableapp/core/services/unit_service.dart';
import 'package:cableapp/core/utils/formatters.dart';
import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/data/models/app_record.dart';
import 'package:cableapp/data/repositories/base_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardProvider = FutureProvider((ref) async {
  final activeUnit = ref.watch(activeUnitIdProvider);
  final custFilters = <String, Object?>{};
  if (activeUnit != null) {
    custFilters['area_id'] = activeUnit;
  }
  final customers = await ref
      .read(repositoryProvider('customers'))
      .list(limit: 1000, filters: custFilters);
  final custIds = customers.map((c) => c.id).toSet();

  final allPayments = await ref
      .read(repositoryProvider('payments'))
      .list(limit: 1000);
  final payments = activeUnit == null
      ? allPayments
      : allPayments
          .where((p) => custIds.contains(p.text('customer_id')))
          .toList();

  final allBills = await ref
      .read(repositoryProvider('monthly_bills'))
      .list(limit: 1000);
  final bills = activeUnit == null
      ? allBills
      : allBills.where((b) => custIds.contains(b.text('customer_id'))).toList();

  return DashboardData(customers, payments, bills);
});

class DashboardData {
  const DashboardData(this.customers, this.payments, this.bills);
  final List<AppRecord> customers;
  final List<AppRecord> payments;
  final List<AppRecord> bills;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard page — with month / year date filter
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime _period = DateTime(DateTime.now().year, DateTime.now().month);
  bool _yearView = false;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  bool get _canGoNext {
    final now = DateTime.now();
    if (_yearView) return _period.year < now.year;
    return _period.year < now.year ||
        (_period.year == now.year && _period.month < now.month);
  }

  void _prev() => setState(() {
        _period = _yearView
            ? DateTime(_period.year - 1)
            : DateTime(_period.year, _period.month - 1);
      });

  void _next() {
    if (!_canGoNext) return;
    setState(() {
      _period = _yearView
          ? DateTime(_period.year + 1)
          : DateTime(_period.year, _period.month + 1);
    });
  }

  List<AppRecord> _filterPayments(List<AppRecord> payments) =>
      payments.where((p) {
        final d = p.date('created_at');
        if (d == null) return false;
        return _yearView
            ? d.year == _period.year
            : d.year == _period.year && d.month == _period.month;
      }).toList();

  List<AppRecord> _filterBills(List<AppRecord> bills) =>
      bills.where((b) {
        if (_yearView) return b.text('bill_year') == '${_period.year}';
        return b.text('bill_year') == '${_period.year}' &&
            b.text('bill_month') == '${_period.month}';
      }).toList();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Column(
        children: [
          const PageHeader(title: 'Dashboard'),
          const SizedBox(height: 16),
          Text('Dashboard could not load: $error'),
        ],
      ),
      data: (data) {
        final fPayments = _filterPayments(data.payments);
        final fBills = _filterBills(data.bills);
        final collection = fPayments.fold<num>(
            0, (s, r) => s + r.number('amount'));
        final pendingAmt = fBills
            .where((e) => e.text('status') == 'pending')
            .fold<num>(0, (s, r) => s + r.number('total_amount'));
        final pendingCount =
            fBills.where((e) => e.text('status') == 'pending').length;

        return ListView(
          children: [
            // ── Header ──────────────────────────────────────────────────
            PageHeader(
              title: 'Dashboard',
              subtitle: 'Customer, billing and payment overview.',
              actions: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Month')),
                    ButtonSegment(value: true, label: Text('Year')),
                  ],
                  selected: {_yearView},
                  onSelectionChanged: (s) =>
                      setState(() => _yearView = s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Date navigation ──────────────────────────────────────────
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _prev,
                      tooltip: 'Previous',
                    ),
                    Expanded(
                      child: Text(
                        _yearView
                            ? '${_period.year}'
                            : '${_months[_period.month - 1]} ${_period.year}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _canGoNext ? _next : null,
                      tooltip: 'Next',
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() =>
                            _period = DateTime(now.year, now.month));
                      },
                      icon: const Icon(Icons.today, size: 16),
                      label: const Text('Today'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(
                              _period.year, _yearView ? 1 : _period.month),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _period =
                              DateTime(picked.year, picked.month));
                        }
                      },
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('Pick date'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── KPI grid ─────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: w < 700 ? 2 : 4,
                  childAspectRatio: w < 700 ? 1.6 : 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _KpiCard('Total customers',
                        '${data.customers.length}', Icons.people_outline),
                    _KpiCard(
                        'Active customers',
                        '${data.customers.where((e) => e.text('status') == 'active').length}',
                        Icons.verified_user_outlined),
                    _KpiCard(
                        _yearView
                            ? 'Yearly collection'
                            : 'Monthly collection',
                        money(collection),
                        Icons.payments_outlined),
                    _KpiCard(
                        _yearView
                            ? 'Yearly pending'
                            : 'Monthly pending',
                        money(pendingAmt),
                        Icons.pending_actions),
                    _KpiCard('Pending customers', '$pendingCount',
                        Icons.person_search_outlined),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Revenue chart ─────────────────────────────────────────────
            _ChartCard(
              title: _yearView
                  ? 'Monthly revenue — ${_period.year}'
                  : 'Daily revenue — ${_months[_period.month - 1]} ${_period.year}',
              child: _RevenueChart(
                payments: fPayments,
                period: _period,
                yearView: _yearView,
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.title, this.value, this.icon);
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bar chart — daily buckets for month view, monthly buckets for year view.
class _RevenueChart extends StatelessWidget {
  const _RevenueChart({
    required this.payments,
    required this.period,
    required this.yearView,
  });
  final List<AppRecord> payments;
  final DateTime period;
  final bool yearView;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final List<BarChartGroupData> groups;

    if (yearView) {
      // 12 monthly buckets
      final totals = List<double>.filled(12, 0);
      for (final p in payments) {
        final d = p.date('created_at');
        if (d != null) totals[d.month - 1] += p.number('amount').toDouble();
      }
      groups = List.generate(
        12,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: totals[i], color: color, width: 14)
          ],
        ),
      );
    } else {
      // Daily buckets for the selected month
      final days = DateUtils.getDaysInMonth(period.year, period.month);
      final totals = List<double>.filled(days, 0);
      for (final p in payments) {
        final d = p.date('created_at');
        if (d != null && d.day <= days) {
          totals[d.day - 1] += p.number('amount').toDouble();
        }
      }
      groups = List.generate(
        days,
        (i) => BarChartGroupData(
          x: i + 1,
          barRods: [
            BarChartRodData(toY: totals[i], color: color, width: 8)
          ],
        ),
      );
    }

    const months = [
      'J','F','M','A','M','J','J','A','S','O','N','D'
    ];

    return BarChart(
      BarChartData(
        barGroups: groups,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                String label;
                if (yearView) {
                  label = idx >= 0 && idx < 12 ? months[idx] : '';
                } else {
                  label = (idx % 5 == 1) ? '$idx' : '';
                }
                return Text(label,
                    style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              money(rod.toY),
              const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}

