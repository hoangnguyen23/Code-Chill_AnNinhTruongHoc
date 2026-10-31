import 'dart:async';

import 'package:campus_core/campus_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/formatters.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/state_views.dart';
import '../application/session.dart';
import '../domain/auth_repository.dart';
import 'auth_scaffold.dart';

/// Đăng ký bước 2: nhập mã 6 số gửi tới email. Đúng mã thì tài khoản được tạo và đăng nhập luôn.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.challenge});

  final OtpChallengeInfo challenge;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  late OtpChallengeInfo _challenge = widget.challenge;
  late DateTime _expiresAt;
  late DateTime _resendAt;
  Timer? _ticker;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

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
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final error = OtpPolicy.validateCode(_code.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyRegistration(_challenge.email, _code.text.trim());
      TextInput.finishAutofillContext();
      // Router tự chuyển vào trang chủ khi đăng nhập xong.
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
      _code.clear();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final next = await ref.read(authRepositoryProvider).requestRegistration(_challenge.draft!);
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
      title: 'Xác nhận email',
      subtitle: 'Nhập mã 6 số vừa gửi tới ${_challenge.emailMasked}.',
      footer: TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Sửa thông tin đăng ký'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoNote(
            'Không thấy email? Xem thêm mục Spam hoặc Quảng cáo. Tài khoản "${_challenge.draft!.username.trim().toLowerCase()}" '
            'chỉ được tạo khi bạn nhập đúng mã.',
            icon: Icons.mark_email_unread_outlined,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(OtpPolicy.codeLength),
            ],
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 12, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(hintText: '••••••', counterText: ''),
            onChanged: (v) {
              if (v.length == OtpPolicy.codeLength && !_verifying) _verify();
            },
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: expired,
            child: Text(
              expired ? 'Mã đã hết hạn. Hãy gửi lại mã.' : 'Mã hết hạn sau ${formatCountdown(expiresIn)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: expired ? scheme.error : scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 16), InlineError(_error!)],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _verifying || expired ? null : _verify,
            child: _verifying
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Xác nhận và tạo tài khoản'),
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
    );
  }
}
