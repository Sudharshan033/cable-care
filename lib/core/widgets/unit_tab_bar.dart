import 'package:cableapp/core/services/unit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnitTabBar extends ConsumerWidget {
  const UnitTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitState = ref.watch(unitProvider);
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 640;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.domain,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          if (!isCompact) ...[
            Text(
              'Place / Unit:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _UnitTabItem(
                    label: unitState.unit1.name,
                    icon: Icons.location_on_outlined,
                    isSelected: unitState.activeUnitId == unitState.unit1.id,
                    onTap: () => ref
                        .read(unitProvider.notifier)
                        .selectUnit(unitState.unit1.id),
                  ),
                  const SizedBox(width: 6),
                  _UnitTabItem(
                    label: unitState.unit2.name,
                    icon: Icons.location_on_outlined,
                    isSelected: unitState.activeUnitId == unitState.unit2.id,
                    onTap: () => ref
                        .read(unitProvider.notifier)
                        .selectUnit(unitState.unit2.id),
                  ),
                  const SizedBox(width: 6),
                  _UnitTabItem(
                    label: 'All Places',
                    icon: Icons.grid_view_outlined,
                    isSelected: unitState.activeUnitId == null,
                    onTap: () =>
                        ref.read(unitProvider.notifier).selectUnit(null),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Customize place names',
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _showRenameDialog(context, ref, unitState),
              icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
              label: Text(
                isCompact ? 'Edit' : 'Rename Places',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    UnitState unitState,
  ) {
    final u1Controller = TextEditingController(text: unitState.unit1.name);
    final u2Controller = TextEditingController(text: unitState.unit2.name);
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.edit_location_outlined, size: 36),
        title: const Text('Customize Place Names'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set custom names for your two operational places/units. All pages and customers will update automatically.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: u1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Place 1 Name',
                    hintText: 'e.g. KK Nagar / Head Office',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: u2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Place 2 Name',
                    hintText: 'e.g. Kkottai / Branch 2',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                await ref.read(unitProvider.notifier).renameUnits(
                      unit1Name: u1Controller.text.trim(),
                      unit2Name: u2Controller.text.trim(),
                    );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Place names updated successfully!')),
                  );
                }
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Save Names'),
          ),
        ],
      ),
    );
  }
}

class _UnitTabItem extends StatelessWidget {
  const _UnitTabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

