import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/role_navigation.dart';
import '../../../core/widgets/state_views.dart';
import '../application/session.dart';
import 'auth_scaffold.dart';

/// Đăng nhập bằng tên đăng nhập (hoặc email) và mật khẩu.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).login(_username.text, _password.text);
      TextInput.finishAutofillContext();
      // Router tự chuyển trang khi phiên đăng nhập thay đổi.
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
      _password.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      title: 'Đăng nhập',
      subtitle: 'Chào mừng bạn quay lại.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Chưa có tài khoản?', style: theme.textTheme.bodyLarge),
          TextButton(onPressed: () => context.push(AppRoutes.register), child: const Text('Đăng ký ngay')),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập hoặc email',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Nhập tên đăng nhập hoặc email.' : null,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'Mật khẩu',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) => (v ?? '').isEmpty ? 'Nhập mật khẩu.' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
              if (_error != null) ...[const SizedBox(height: 8), InlineError(_error!)],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
