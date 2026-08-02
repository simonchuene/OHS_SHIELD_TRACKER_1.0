// path: lib/features/user_admin/presentation/screens/invite_user_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/utils/validators.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/user_filter.dart';
import 'package:ohs_shield_tracker/features/user_admin/presentation/providers/user_admin_providers.dart';

/// Invite (provision) a new user. Admin-only; the request runs through the
/// service-role Edge Function. The invitee sets their own password → the
/// activation trigger flips their profile to `active`.
class InviteUserScreen extends ConsumerStatefulWidget {
  const InviteUserScreen({super.key});
  @override
  ConsumerState<InviteUserScreen> createState() => _InviteUserScreenState();
}

/// Role scope options (company-wide vs. site-/department-scoped).
enum _Scope { companyWide, site, department }

class _InviteUserScreenState extends ConsumerState<InviteUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _jobTitle = TextEditingController();
  final _phone = TextEditingController();

  AppRole _role = AppRole.employee;
  _Scope _scope = _Scope.companyWide;
  String? _siteId;
  String? _departmentId;

  @override
  void dispose() {
    for (final c in [_email, _first, _last, _jobTitle, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scope != _Scope.companyWide && _siteId == null) {
      _snack('Select a site for the chosen scope.');
      return;
    }
    if (_scope == _Scope.department && _departmentId == null) {
      _snack('Select a department for department scope.');
      return;
    }

    final params = InviteUserParams(
      email: _email.text.trim(),
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      jobTitle: _jobTitle.text.trim().isEmpty ? null : _jobTitle.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      siteId: _siteId,
      departmentId: _scope == _Scope.department ? _departmentId : null,
      role: _role,
      roleSiteId: _scope == _Scope.companyWide ? null : _siteId,
      roleDepartmentId: _scope == _Scope.department ? _departmentId : null,
    );

    final ok = await ref.read(userAdminActionControllerProvider.notifier).invite(params);
    if (!mounted) return;
    if (ok) {
      _snack('Invite sent to ${params.email}');
      context.pop();
    } else {
      final f = ref.read(userAdminActionControllerProvider).error;
      _snack(f is Failure ? f.message : 'Invite failed');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(companySitesProvider);
    final busy = ref.watch(userAdminActionControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Invite user')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *', hintText: 'name@company.com'),
                validator: Validators.email,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _first, decoration: const InputDecoration(labelText: 'First name *'), validator: (v) => Validators.required(v, field: 'First name'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _last, decoration: const InputDecoration(labelText: 'Last name *'), validator: (v) => Validators.required(v, field: 'Last name'))),
              ],),
              const SizedBox(height: 12),
              TextFormField(controller: _jobTitle, decoration: const InputDecoration(labelText: 'Job title')),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 20),
              DropdownButtonFormField<AppRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role *'),
                items: [for (final r in AppRole.values) DropdownMenuItem(value: r, child: Text(r.name))],
                onChanged: (v) => setState(() => _role = v ?? AppRole.employee),
              ),
              const SizedBox(height: 20),
              Text('Role scope', style: Theme.of(context).textTheme.titleLarge),
              RadioListTile<_Scope>(value: _Scope.companyWide, groupValue: _scope, onChanged: (v) => setState(() => _scope = v!), title: const Text('Company-wide')),
              RadioListTile<_Scope>(value: _Scope.site, groupValue: _scope, onChanged: (v) => setState(() => _scope = v!), title: const Text('Site-scoped')),
              RadioListTile<_Scope>(value: _Scope.department, groupValue: _scope, onChanged: (v) => setState(() => _scope = v!), title: const Text('Department-scoped')),
              if (_scope != _Scope.companyWide)
                sites.when(
                  loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
                  error: (e, _) => Text('Could not load sites: $e'),
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _siteId,
                    decoration: const InputDecoration(labelText: 'Site *'),
                    items: [for (final s in list) DropdownMenuItem(value: s.id, child: Text(s.name))],
                    onChanged: (v) => setState(() {
                      _siteId = v;
                      _departmentId = null;
                    }),
                  ),
                ),
              if (_scope == _Scope.department && _siteId != null)
                ref.watch(siteDepartmentsProvider(_siteId!)).when(
                      loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
                      error: (e, _) => Text('Could not load departments: $e'),
                      data: (list) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: _departmentId,
                          decoration: const InputDecoration(labelText: 'Department *'),
                          items: [for (final d in list) DropdownMenuItem(value: d.id, child: Text(d.name))],
                          onChanged: (v) => setState(() => _departmentId = v),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send invite'),
              ),
              const SizedBox(height: 8),
              Text('The user receives an email to set their password. Their account activates once they accept.',
                  style: Theme.of(context).textTheme.labelSmall,),
            ],
          ),
        ),
      ),
    );
  }
}
