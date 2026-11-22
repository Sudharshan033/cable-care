import 'package:cableapp/core/utils/formatters.dart';
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'active' || 'paid' || 'completed' || 'available' => Colors.green,
      'partial' || 'partially_paid' => Colors.amber.shade800,
      'pending' || 'assigned' || 'in_progress' => Colors.orange,
      'suspended' || 'repair' => Colors.blueGrey,
      'disconnected' || 'damaged' || 'closed' => Colors.red,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(labelize(status), overflow: TextOverflow.ellipsis),
      side: BorderSide(color: color.withValues(alpha: .3)),
      backgroundColor: color.withValues(alpha: .12),
    );
  }
}
