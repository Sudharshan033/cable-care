import 'package:cableapp/data/supabase_client.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationService {
  Future<void> openWhatsApp({
    required String phone,
    required String message,
  }) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final formatted = clean.startsWith('91') ? clean : '91$clean';
    final uri = Uri.parse(
      'https://wa.me/$formatted?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    await _log(
      phone: phone,
      message: message,
      channel: 'whatsapp',
      status: 'sent',
    );
  }

  Future<void> openSMS({
    required String phone,
    required String message,
  }) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('sms:$clean?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
    await _log(
      phone: phone,
      message: message,
      channel: 'sms',
      status: 'sent',
    );
  }

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
