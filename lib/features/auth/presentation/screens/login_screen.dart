// path: lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/core/utils/validators.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';

/// Login screen — visual hierarchy per Master Prompt Login Screen Branding:
/// Logo -> App Name -> Tagline -> Email -> Password -> Login. Brand accent
/// stripe (Item 1b) on the top edge; primary filled-green CTA (16px radius).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(signInControllerProvider.notifier).signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
    // On success the auth-state change triggers the router redirect to /dashboard.
    if (!ok && mounted) {
      final failure = ref.read(signInControllerProvider).error;
      final message = failure is Failure ? failure.message : 'Sign in failed. Try again.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInControllerProvider);
    final loading = state.isLoading;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          Container(height: 4, color: AppColors.brandAccent), // brand accent stripe (Item 1b)
          Expanded(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/branding/app_icon.png', width: 96, height: 96),
                        const SizedBox(height: 16),
                        Text('OHS Shield Tracker',
                            style: textTheme.headlineMedium, textAlign: TextAlign.center,),
                        const SizedBox(height: 8),
                        // Tagline: centred, secondary text, max 2 lines (Master Prompt).
                        Text(
                          'Transforming safety metrics into operational strength',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 40),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'name@company.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: Validators.password,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push(Routes.forgotPassword),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),)
                                : const Text('Log in'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Secured with role-based access',
                            style: textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
