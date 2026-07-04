import 'package:cableapp/data/supabase_client.dart';

class NotificationService {
  Future<void> sendSMS({required String phone, required String message}) async {
    await _log(
      phone: phone,
      message: message,
      channel: 'sms',
      status: 'queued',
    );
  }

  Future<void> sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    await _log(
      phone: phone,
      message: message,
      channel: 'whatsapp',
      status: 'queued',
    );
  }

  Future<void> _log({
    required String phone,
    required String message,
    required String channel,
    required String status,
  }) {
    return supabase.from('notifications').insert({
      'recipient_phone': phone,
      'message': message,
      'channel': channel,
      'status': status,
    });
  }
}
