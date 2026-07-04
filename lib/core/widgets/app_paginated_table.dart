import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

class AppPaginatedTable extends StatelessWidget {
  const AppPaginatedTable({
    required this.columns,
    required this.rows,
    this.minWidth = 900,
    super.key,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 540,
        child: DataTable2(
          minWidth: minWidth,
          columns: columns,
          rows: rows,
          headingRowColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          ),
        ),
      ),
    );
  }
}
