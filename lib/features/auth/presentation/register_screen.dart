import 'package:campus_core/campus_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/role_navigation.dart';
import '../../../core/widgets/state_views.dart';
import '../application/session.dart';
import '../domain/auth_repository.dart';
import 'auth_scaffold.dart';

/// Đăng ký bước 1: họ tên, email, tên đăng nhập, mật khẩu. Bấm gửi thì backend gửi mã OTP tới
/// email; tài khoản chỉ được tạo khi nhập đúng mã ở bước 2.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    for (final c in [_name, _email, _username, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    // Tài khoản mới mặc định là Sinh viên; quản trị đổi sang Giảng viên nếu cần.
    final draft = RegistrationDraft(
      email: _email.text,
      username: _username.text,
      password: _password.text,
      displayName: _name.text,
    );
    try {
      final challenge = await ref.read(authRepositoryProvider).requestRegistration(draft);
      if (mounted) await context.push(AppRoutes.registerOtp, extra: challenge);
    } on ApiError catch (e) {
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      showBack: true,
      step: 'Bước 1/2',
      title: 'Tạo tài khoản',
      subtitle: 'Mã xác nhận sẽ được gửi tới email của bạn.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Đã có tài khoản?', style: theme.textTheme.bodyLarge),
          TextButton(onPressed: () => context.pop(), child: const Text('Đăng nhập')),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                maxLength: ProfileLimits.maxNameLength,
                forceErrorText: _fieldErrors['displayName'],
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.badge_outlined),
                  counterText: '',
                ),
                validator: ProfileLimits.validateDisplayName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
                forceErrorText: _fieldErrors['email'],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'ten@gmail.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: EmailAddress.validate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                autocorrect: false,
                enableSuggestions: false,
                forceErrorText: _fieldErrors['username'],
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập',
                  hintText: 'vd: kien.nguyen',
                  helperText: 'Chữ không dấu, số, dấu chấm hoặc gạch dưới; 3 đến 30 ký tự.',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: UsernamePolicy.validate,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'Mật khẩu',
                helperText: 'Ít nhất ${PasswordPolicy.minLength} ký tự, có cả chữ và số.',
                autofillHints: const [AutofillHints.newPassword],
                errorText: _fieldErrors['password'],
                validator: PasswordPolicy.validate,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: 'Nhập lại mật khẩu',
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp.' : null,
              ),
              if (_error != null) ...[const SizedBox(height: 16), InlineError(_error!)],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.mark_email_read_outlined),
                label: Text(_busy ? 'Đang gửi mã…' : 'Gửi mã xác nhận'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
