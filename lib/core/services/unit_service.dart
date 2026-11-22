import 'package:cableapp/data/supabase_client.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnitModel {
  const UnitModel({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  UnitModel copyWith({String? name}) => UnitModel(
        id: id,
        name: name ?? this.name,
        code: code,
      );
}

const defaultUnit1Id = '11111111-1111-1111-1111-111111111111';
const defaultUnit2Id = '22222222-2222-2222-2222-222222222222';

class UnitState {
  const UnitState({
    required this.unit1,
    required this.unit2,
    required this.activeUnitId,
    this.isLoading = false,
  });

  final UnitModel unit1;
  final UnitModel unit2;
  final String? activeUnitId; // null = 'all'
  final bool isLoading;

  UnitModel? get activeUnit {
    if (activeUnitId == unit1.id) return unit1;
    if (activeUnitId == unit2.id) return unit2;
    return null;
  }

  UnitState copyWith({
    UnitModel? unit1,
    UnitModel? unit2,
    String? activeUnitId,
    bool forceActiveUnitNull = false,
    bool? isLoading,
  }) {
    return UnitState(
      unit1: unit1 ?? this.unit1,
      unit2: unit2 ?? this.unit2,
      activeUnitId:
          forceActiveUnitNull ? null : (activeUnitId ?? this.activeUnitId),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UnitNotifier extends StateNotifier<UnitState> {
  UnitNotifier()
      : super(const UnitState(
          unit1: UnitModel(
            id: defaultUnit1Id,
            name: 'Unit 1',
            code: 'UNIT_1',
          ),
          unit2: UnitModel(
            id: defaultUnit2Id,
            name: 'Unit 2',
            code: 'UNIT_2',
          ),
          activeUnitId: defaultUnit1Id,
        )) {
    loadUnits();
  }

  Future<void> loadUnits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedActive = prefs.getString('active_unit_id');
      final localUnit1Name = prefs.getString('unit_1_name');
      final localUnit2Name = prefs.getString('unit_2_name');

      var u1Name = localUnit1Name ?? 'Unit 1';
      var u2Name = localUnit2Name ?? 'Unit 2';

      if (isSupabaseReady) {
        final res = await supabase
            .from('areas')
            .select()
            .inFilter('code', ['UNIT_1', 'UNIT_2']);
        final list = (res as List).cast<Map<String, dynamic>>();
        for (final item in list) {
          if (item['code'] == 'UNIT_1') {
            final n = item['name'] as String?;
            if (n != null && n.trim().isNotEmpty) u1Name = n.trim();
          } else if (item['code'] == 'UNIT_2') {
            final n = item['name'] as String?;
            if (n != null && n.trim().isNotEmpty) u2Name = n.trim();
          }
        }
      }

      state = state.copyWith(
        unit1: state.unit1.copyWith(name: u1Name),
        unit2: state.unit2.copyWith(name: u2Name),
        activeUnitId:
            savedActive == 'all' ? null : (savedActive ?? defaultUnit1Id),
        forceActiveUnitNull: savedActive == 'all',
      );
    } catch (_) {}
  }

  Future<void> selectUnit(String? unitId) async {
    state = state.copyWith(
      activeUnitId: unitId,
      forceActiveUnitNull: unitId == null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_unit_id', unitId ?? 'all');
  }

  Future<void> renameUnits({
    required String unit1Name,
    required String unit2Name,
  }) async {
    final cleanU1 = unit1Name.trim().isEmpty ? 'Unit 1' : unit1Name.trim();
    final cleanU2 = unit2Name.trim().isEmpty ? 'Unit 2' : unit2Name.trim();

    state = state.copyWith(
      unit1: state.unit1.copyWith(name: cleanU1),
      unit2: state.unit2.copyWith(name: cleanU2),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unit_1_name', cleanU1);
    await prefs.setString('unit_2_name', cleanU2);

    if (isSupabaseReady) {
      await supabase.from('areas').upsert([
        {'id': defaultUnit1Id, 'name': cleanU1, 'code': 'UNIT_1'},
        {'id': defaultUnit2Id, 'name': cleanU2, 'code': 'UNIT_2'},
      ], onConflict: 'code');
    }
  }
}

final unitProvider = StateNotifierProvider<UnitNotifier, UnitState>((ref) {
  return UnitNotifier();
});

final activeUnitIdProvider = Provider<String?>((ref) {
  return ref.watch(unitProvider).activeUnitId;
});

