// path: lib/features/auth/presentation/screens/set_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';

/// Where both email-link journeys land: an invitee choosing their first
/// password, and a user completing a reset.
///
/// The link has already established a session by the time this screen shows —
/// that is what makes `updateUser(password:)` legal without the old password.
/// The screen exists because there was previously nowhere for either flow to
/// go, so both emails were dead ends.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref.read(setPasswordControllerProvider.notifier).submit(_password.text);
    if (!mounted) return;
    if (ok) {
      // The gate is cleared by the controller, so the router redirect releases
      // and lands the user on the dashboard with an ordinary session.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Password set')));
    } else {
      final f = ref.read(setPasswordControllerProvider).error;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f is Failure ? f.message : 'Could not set the password')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(setPasswordControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Set your password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                'Choose a password for your account. You will use it to sign in from now on.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                // Supabase's own minimum is 6; anything stricter here would be
                // rejected client-side while the server still accepts it.
                validator: (v) => (v == null || v.length < 6)
                    ? 'Use at least 6 characters'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'Confirm password'),
                validator: (v) => v != _password.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Set password'),
              ),
            ],),
          ),
        ),
      ),
    );
  }
}
