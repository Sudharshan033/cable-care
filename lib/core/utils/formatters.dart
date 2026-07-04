import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
final _date = DateFormat('dd MMM yyyy');

String money(num value) => _currency.format(value);
String shortDate(DateTime value) => _date.format(value);
String labelize(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
