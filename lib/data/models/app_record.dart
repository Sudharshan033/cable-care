class AppRecord {
  const AppRecord(this.data);
  final Map<String, dynamic> data;

  String get id => '${data['id'] ?? ''}';
  String text(String key, [String fallback = '-']) {
    final value = data[key];
    if (value == null || '$value'.isEmpty) return fallback;
    return '$value';
  }

  num number(String key) {
    final value = data[key];
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  DateTime? date(String key) {
    final value = data[key];
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
