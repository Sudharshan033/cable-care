import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/data/repositories/base_repository.dart';
import 'package:cableapp/features/shared/module_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({this.id, super.key});
  final String? id;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final formKey = GlobalKey<FormBuilderState>();
  bool saving = false;
  Map<String, dynamic>? initial;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final record = await ref
        .read(repositoryProvider('customers'))
        .byId(widget.id!);
    if (mounted) {
      final data = record?.data ?? {};
      // FormBuilderTextField expects String? for initialValue.
      // Supabase returns numeric columns as int/double — convert them to String.
      final normalized = data.map<String, dynamic>((key, value) {
        if (value is num) return MapEntry(key, value.toString());
        return MapEntry(key, value);
      });
      setState(() => initial = normalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a spinner while fetching existing data for edit mode.
    // This ensures FormBuilder.initialValue is set correctly on first render.
    if (widget.id != null && initial == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      children: [
        PageHeader(title: widget.id == null ? 'Add Customer' : 'Edit Customer'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FormBuilder(
              key: formKey,
              initialValue: initial ?? const {},
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field('name', 'Name', required: true),
                  _field('phone', 'Phone', required: true),
                  _field('alternate_number', 'Alternate number'),
                  _field('email', 'Email'),
                  _field('address', 'Address', width: 620),
                  _field('village', 'Village'),
                  _field('pincode', 'Pincode'),
                  _field('box_id', 'Box ID'),
                  _field('vc_number', 'VC number'),
                  _field('smart_card_number', 'Smart card number'),
                  _field('monthly_charge', 'Monthly charge', number: true),
                  _field(
                    'installation_charge',
                    'Installation charge',
                    number: true,
                  ),
                  _field('security_deposit', 'Security deposit', number: true),
                  SizedBox(
                    width: 300,
                    child: FormBuilderDropdown<String>(
                      name: 'status',
                      initialValue: initial?['status'] ?? 'active',
                      decoration: const InputDecoration(labelText: 'Status'),
                      items:
                          const [
                                'active',
                                'inactive',
                                'suspended',
                                'disconnected',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  _field('notes', 'Notes', width: 620),
                  SizedBox(
                    width: 620,
                    child: Row(
                      children: [
                        FilledButton.icon(
                          onPressed: saving ? null : _save,
                          icon: saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save customer'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => context.go('/customers'),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    String name,
    String label, {
    bool required = false,
    bool number = false,
    double width = 300,
  }) {
    return SizedBox(
      width: width,
      child: FormBuilderTextField(
        name: name,
        decoration: InputDecoration(labelText: label),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        validator: required ? FormBuilderValidators.required() : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.saveAndValidate() ?? false)) {
      return;
    }
    setState(() => saving = true);
    final payload = Map<String, dynamic>.from(formKey.currentState!.value);
    if (widget.id != null) {
      payload['id'] = widget.id;
    }
    for (final key in [
      'monthly_charge',
      'installation_charge',
      'security_deposit',
    ]) {
      payload[key] = num.tryParse('${payload[key] ?? 0}') ?? 0;
    }
    try {
      await ref.read(repositoryProvider('customers')).upsert(payload);
      if (mounted) {
        // Invalidate the list cache so the customers list re-fetches fresh data.
        ref.invalidate(moduleRowsProvider);
        context.go('/customers');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }
}
