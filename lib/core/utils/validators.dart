String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

String? phoneText(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Required';
  return RegExp(r'^[0-9]{10}$').hasMatch(text)
      ? null
      : 'Enter a 10 digit phone';
}
