import 'package:cableapp/core/widgets/page_header.dart';
import 'package:cableapp/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return ListView(
      children: [
        const PageHeader(title: 'Profile'),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text((user?.email ?? 'A').substring(0, 1).toUpperCase()),
            ),
            title: Text(user?.email ?? 'Admin'),
            subtitle: const Text('Single admin login'),
            trailing: FilledButton.icon(
              onPressed: () async {
                final email = ref.read(currentUserProvider)?.email ?? '';
                if (email.isNotEmpty) {
                  await ref
                      .read(authControllerProvider)
                      .resetPassword(email);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email sent'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.lock_reset),
              label: const Text('Change password'),
            ),
          ),
        ),
      ],
    );
  }
}
