// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Customer _$CustomerFromJson(Map<String, dynamic> json) => _Customer(
  id: json['id'] as String?,
  customerCode: json['customerCode'] as String?,
  name: json['name'] as String,
  phone: json['phone'] as String,
  email: json['email'] as String?,
  address: json['address'] as String?,
  areaId: json['areaId'] as String?,
  status: json['status'] as String? ?? 'active',
  monthlyCharge: json['monthlyCharge'] as num? ?? 0,
);

Map<String, dynamic> _$CustomerToJson(_Customer instance) => <String, dynamic>{
  'id': instance.id,
  'customerCode': instance.customerCode,
  'name': instance.name,
  'phone': instance.phone,
  'email': instance.email,
  'address': instance.address,
  'areaId': instance.areaId,
  'status': instance.status,
  'monthlyCharge': instance.monthlyCharge,
};
