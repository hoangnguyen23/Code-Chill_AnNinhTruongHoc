import 'package:campus_core/campus_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/state_views.dart';
import '../application/session.dart';

/// Lần đầu đăng nhập: nhập họ tên, số điện thoại (tuỳ chọn) và đối tượng.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            displayName: _name.text.trim(),
            phone: _phone.text.trim(),
          );
      // Router tự chuyển sang trang chủ khi hồ sơ cập nhật.
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(signedInUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoàn tất hồ sơ'),
        actions: [
          TextButton(onPressed: () => ref.read(authRepositoryProvider).signOut(), child: const Text('Đăng xuất')),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                'Tên của bạn giúp bảo vệ liên hệ khi cần. Khi gửi báo cáo bạn vẫn có thể chọn ẩn danh.',
                style: theme.textTheme.bodyLarge,
              ),
              if (user != null) ...[
                const SizedBox(height: 8),
                Text('Email: ${user.email}', style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                maxLength: ProfileLimits.maxNameLength,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: ProfileLimits.validateDisplayName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ .\-]'))],
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại (không bắt buộc)',
                  hintText: '0912 345 678',
                  helperText: 'Để bảo vệ gọi lại khi cần.',
                ),
                validator: validateOptionalPhone,
              ),
              const SizedBox(height: 16),
              if (user != null)
                InfoNote(
                  'Bạn là: ${user.memberType.label}. Đối tượng do quản trị xác nhận.',
                  icon: Icons.badge_outlined,
                ),
              if (_error != null) ...[const SizedBox(height: 16), InlineError(_error!)],
              const SizedBox(height: 24),
              FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Đang lưu…' : 'Tiếp tục')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Số điện thoại không bắt buộc: để trống thì hợp lệ, có nhập thì phải là số di động Việt Nam.
String? validateOptionalPhone(String? value) =>
    (value == null || value.trim().isEmpty) ? null : VietnamPhone.validate(value);
