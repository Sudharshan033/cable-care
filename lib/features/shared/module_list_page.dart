import 'package:cableapp/core/utils/file_download.dart';
import 'package:cableapp/core/widgets/app_paginated_table.dart';
import 'package:cableapp/core/widgets/empty_state.dart';
import 'package:cableapp/core/widgets/error_state.dart';
import 'package:cableapp/core/widgets/loading_skeleton.dart';
import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/core/widgets/status_badge.dart';
import 'package:cableapp/data/models/app_record.dart';
import 'package:cableapp/data/repositories/base_repository.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ModuleConfig {
  const ModuleConfig({
    required this.title,
    required this.table,
    required this.columns,
    this.subtitle,
    this.searchColumns = const [],
    this.statusColumn,
    this.addPath,
  });

  final String title;
  final String? subtitle;
  final String table;
  final List<String> columns;
  final List<String> searchColumns;
  final String? statusColumn;
  final String? addPath;
}

class ModuleListPage extends ConsumerStatefulWidget {
  const ModuleListPage({required this.config, super.key});
  final ModuleConfig config;

  @override
  ConsumerState<ModuleListPage> createState() => _ModuleListPageState();
}

class _ModuleListPageState extends ConsumerState<ModuleListPage> {
  String search = '';
  List<AppRecord>? _cachedRecords;

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(moduleRowsProvider((widget.config, search)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: widget.config.title,
          subtitle: widget.config.subtitle,
          actions: [
            SizedBox(
              width: 280,
              child: SearchBar(
                leading: const Icon(Icons.search),
                hintText: 'Search',
                onChanged: (value) => setState(() => search = value),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _cachedRecords == null || _cachedRecords!.isEmpty
                  ? null
                  : () => _exportExcel(_cachedRecords!),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export'),
            ),
            if (widget.config.addPath != null)
              FilledButton.icon(
                onPressed: () => context.go(widget.config.addPath!),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: rows.when(
            loading: () => const LoadingSkeleton(),
            error: (error, _) => ErrorState(
              message: '$error',
              onRetry: () =>
                  ref.invalidate(moduleRowsProvider((widget.config, search))),
            ),
            data: (records) {
              _cachedRecords = records;
              if (records.isEmpty) {
                return EmptyState(
                  title: 'No ${widget.config.title.toLowerCase()} yet',
                );
              }
              return AppPaginatedTable(
                columns: [
                  for (final column in widget.config.columns)
                    DataColumn(label: Text(_header(column))),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final record in records)
                    DataRow(
                      cells: [
                        for (final column in widget.config.columns)
                          DataCell(
                            widget.config.statusColumn == column
                                ? StatusBadge(record.text(column))
                                : Text(
                                    record.text(column),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        DataCell(
                          IconButton(
                            tooltip: 'Open',
                            icon: const Icon(Icons.open_in_new),
                            onPressed:
                                widget.config.addPath?.startsWith(
                                      '/customers',
                                    ) ==
                                    true
                                ? () => context.go('/customers/${record.id}')
                                : null,
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _header(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');

  void _exportExcel(List<AppRecord> records) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Sheet1'];

    // Header row
    sheet.appendRow(
      widget.config.columns
          .map((c) => TextCellValue(_header(c)))
          .toList(),
    );

    // Data rows
    for (final record in records) {
      sheet.appendRow(
        widget.config.columns
            .map((c) => TextCellValue(record.text(c, '')))
            .toList(),
      );
    }

    final bytes = workbook.encode();
    if (bytes == null) return;
    final filename =
        '${widget.config.title.toLowerCase().replaceAll(' ', '_')}.xlsx';
    downloadBytes(bytes, filename);
  }
}

/// Public provider — expose so form pages can call ref.invalidate(moduleRowsProvider)
/// after a successful save to force the list to re-fetch fresh data.
final moduleRowsProvider =
    FutureProvider.family<List<AppRecord>, (ModuleConfig, String)>((ref, args) {
      final (config, search) = args;
      return ref
          .read(repositoryProvider(config.table))
          .list(search: search, searchColumns: config.searchColumns);
    });
