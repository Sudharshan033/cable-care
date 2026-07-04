import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';

class StbsPage extends StatelessWidget {
  const StbsPage({super.key});
  @override
  Widget build(BuildContext context) => const ModuleListPage(
    config: ModuleConfig(
      title: 'Set Top Boxes',
      table: 'set_top_boxes',
      columns: [
        'box_id',
        'vc_number',
        'brand',
        'model',
        'serial_number',
        'status',
      ],
      searchColumns: [
        'box_id',
        'vc_number',
        'smart_card_number',
        'serial_number',
      ],
      statusColumn: 'status',
    ),
  );
}
