import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer.freezed.dart';
part 'customer.g.dart';

@freezed
abstract class Customer with _$Customer {
  const factory Customer({
    String? id,
    String? customerCode,
    required String name,
    required String phone,
    String? email,
    String? address,
    String? areaId,
    @Default('active') String status,
    @Default(0) num monthlyCharge,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);
}
