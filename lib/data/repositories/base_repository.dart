import 'package:cableapp/data/models/app_record.dart';
import 'package:cableapp/data/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BaseRepository {
  const BaseRepository(this.table);
  final String table;

  Future<List<AppRecord>> list({
    String? search,
    List<String> searchColumns = const [],
    Map<String, Object?> filters = const {},
    int limit = 100,
  }) async {
    var query = supabase.from(table).select();
    for (final entry in filters.entries) {
      if (entry.value != null && '${entry.value}'.isNotEmpty) {
        query = query.eq(entry.key, entry.value!);
      }
    }
    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);
    final lower = (search ?? '').trim().toLowerCase();
    final rows = (response as List).cast<Map<String, dynamic>>();
    return rows.map(AppRecord.new).where((record) {
      if (lower.isEmpty || searchColumns.isEmpty) return true;
      return searchColumns.any(
        (column) => record.text(column, '').toLowerCase().contains(lower),
      );
    }).toList();
  }

  Future<AppRecord?> byId(String id) async {
    final response = await supabase
        .from(table)
        .select()
        .eq('id', id)
        .maybeSingle();
    return response == null ? null : AppRecord(response);
  }

  Future<void> upsert(Map<String, dynamic> payload) async {
    final clean = Map<String, dynamic>.from(payload)
      ..removeWhere(
        (_, value) => value == null || (value is String && value.isEmpty),
      );
    await supabase.from(table).upsert(clean);
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    final clean = Map<String, dynamic>.from(payload)
      ..removeWhere(
        (_, value) => value == null || (value is String && value.isEmpty),
      );
    await supabase.from(table).update(clean).eq('id', id);
  }

  Future<void> delete(String id) async {
    await supabase.from(table).delete().eq('id', id);
  }
}

final repositoryProvider = Provider.family<BaseRepository, String>(
  (_, table) => BaseRepository(table),
);
