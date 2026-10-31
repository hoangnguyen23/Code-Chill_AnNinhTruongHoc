import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../campus/campus_info.dart';
import '../../campus/hotline_button.dart';
import 'server_url_dialog.dart';

/// Khung chung cho màn đăng nhập, đăng ký, xác nhận email: dải màu thương hiệu ở trên, thẻ
/// nội dung nổi lên phía dưới, nút gọi trực ở cuối (khi trường đã cấu hình số trực).
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.step,
    this.footer,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Ví dụ "Bước 1/2".
  final String? step;
  final Widget? footer;
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final campus = ref.watch(campusInfoProvider).value;
    final hasHotline = campus?.hasHotline ?? false;
    final bandTop = isDark ? scheme.primaryContainer : scheme.primary;
    final bandBottom = isDark ? scheme.surfaceContainerHigh : const Color(0xFF173B7A);
    final onBand = isDark ? scheme.onPrimaryContainer : scheme.onPrimary;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bandTop, bandBottom],
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 72),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            if (showBack)
                              IconButton(
                                tooltip: 'Quay lại',
                                onPressed: () => Navigator.of(context).maybePop(),
                                icon: Icon(Icons.arrow_back_rounded, color: onBand),
                              ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Địa chỉ máy chủ',
                              onPressed: () => showServerUrlDialog(context),
                              icon: Icon(Icons.dns_outlined, color: onBand),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: onBand.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.shield_rounded, size: 32, color: onBand),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppConfig.appName,
                                  style: theme.textTheme.headlineSmall?.copyWith(color: onBand, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  (campus != null && campus.campusName.isNotEmpty)
                                      ? campus.campusName
                                      : 'Báo sự cố, khẩn cấp, đi về an toàn',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: onBand.withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          color: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
                          elevation: 3,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (step != null)
                                  Text(
                                    step!.toUpperCase(),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: scheme.primary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 24),
                                child,
                              ],
                            ),
                          ),
                        ),
                        if (footer != null) ...[const SizedBox(height: 16), footer!],
                        if (hasHotline) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Đang gặp nguy hiểm và chưa đăng nhập được?',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          const HotlineButton(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô mật khẩu có nút hiện/ẩn.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.helperText,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final String? helperText;

  /// Lỗi từ máy chủ (ví dụ mật khẩu không đạt yêu cầu).
  final String? errorText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      forceErrorText: widget.errorText,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _visible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
          onPressed: () => setState(() => _visible = !_visible),
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        ),
      ),
    );
  }
}
