import 'dart:async';

import 'package:campus_core/campus_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/formatters.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/role_navigation.dart';
import '../../../core/widgets/state_views.dart';
import '../application/session.dart';
import '../domain/auth_repository.dart';
import 'auth_scaffold.dart';

/// Quên mật khẩu bước 1: nhập email của tài khoản để nhận mã OTP.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final challenge = await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
      if (mounted) await context.push(AppRoutes.resetPassword, extra: challenge);
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      step: 'Bước 1/2',
      title: 'Quên mật khẩu',
      subtitle: 'Nhập email của tài khoản. Mã xác nhận sẽ được gửi tới email đó.',
      footer: TextButton(onPressed: () => context.pop(), child: const Text('Quay lại đăng nhập')),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Email của tài khoản',
                hintText: 'ten@gmail.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: EmailAddress.validate,
              onFieldSubmitted: (_) => _submit(),
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
    );
  }
}

/// Quên mật khẩu bước 2: nhập mã OTP và mật khẩu mới. Đúng mã thì đổi mật khẩu và đăng nhập luôn.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.challenge});

  final OtpChallengeInfo challenge;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late OtpChallengeInfo _challenge = widget.challenge;
  late DateTime _expiresAt;
  late DateTime _resendAt;
  Timer? _ticker;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _startTimers();
  }

  void _startTimers() {
    final now = DateTime.now();
    _expiresAt = now.add(_challenge.expiresIn);
    _resendAt = now.add(_challenge.resendAfter);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_code, _password, _confirm]) {
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
    try {
      await ref.read(authRepositoryProvider).resetPassword(_challenge.email, _code.text.trim(), _password.text);
      TextInput.finishAutofillContext();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
      }
      // Router tự chuyển vào trang chủ khi đăng nhập xong.
    } on ApiError catch (e) {
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
      });
      if (e.code.startsWith('otp_')) _code.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final next = await ref.read(authRepositoryProvider).requestPasswordReset(_challenge.email);
      setState(() {
        _challenge = next;
        _code.clear();
        _startTimers();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi mã mới vào email.')));
      }
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final expiresIn = _expiresAt.difference(now);
    final resendIn = _resendAt.difference(now);
    final expired = expiresIn.isNegative;

    return AuthScaffold(
      showBack: true,
      step: 'Bước 2/2',
      title: 'Đặt mật khẩu mới',
      subtitle: 'Nhập mã 6 số vừa gửi tới ${_challenge.emailMasked} và mật khẩu mới.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoNote(
                'Không thấy email? Xem thêm mục Spam hoặc Quảng cáo. Mật khẩu chỉ được đổi khi mã đúng.',
                icon: Icons.mark_email_unread_outlined,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(OtpPolicy.codeLength),
                ],
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 10, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(labelText: 'Mã OTP', hintText: '••••••', counterText: ''),
                validator: OtpPolicy.validateCode,
              ),
              const SizedBox(height: 6),
              Text(
                expired ? 'Mã đã hết hạn. Hãy gửi lại mã.' : 'Mã hết hạn sau ${formatCountdown(expiresIn)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: expired ? scheme.error : scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'Mật khẩu mới',
                helperText: 'Ít nhất ${PasswordPolicy.minLength} ký tự, có cả chữ và số.',
                autofillHints: const [AutofillHints.newPassword],
                errorText: _fieldErrors['password'],
                validator: PasswordPolicy.validate,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: 'Nhập lại mật khẩu mới',
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp.' : null,
              ),
              if (_error != null) ...[const SizedBox(height: 16), InlineError(_error!)],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy || expired ? null : _submit,
                child: _busy
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Đổi mật khẩu'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: (resendIn.isNegative && !_resending) ? _resend : null,
                child: Text(
                  _resending
                      ? 'Đang gửi lại…'
                      : resendIn.isNegative
                          ? 'Gửi lại mã'
                          : 'Gửi lại mã sau ${formatCountdown(resendIn)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
