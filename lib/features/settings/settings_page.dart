import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/data/repositories/base_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageHeader(
          title: 'Settings',
          subtitle:
              'Company info, billing defaults, receipt footer, and admin utilities.',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FormBuilder(
              key: formKey,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field('company_name', 'Company name'),
                  _field('address', 'Address', width: 620),
                  _field('gst_number', 'GST number'),
                  _field('default_monthly_charge', 'Default monthly charge'),
                  _field('late_fine', 'Late fine'),
                  _field('currency', 'Currency'),
                  _field('receipt_footer', 'Receipt footer', width: 620),
                  SizedBox(
                    width: 620,
                    child: FilledButton.icon(
                      onPressed: () async {
                        formKey.currentState?.save();
                        await ref
                            .read(repositoryProvider('settings'))
                            .upsert(formKey.currentState?.value ?? {});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings saved')),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save settings'),
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

  Widget _field(String name, String label, {double width = 300}) {
    return SizedBox(
      width: width,
      child: FormBuilderTextField(
        name: name,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

