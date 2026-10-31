import 'dart:async';

import 'package:campus_core/campus_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/formatters.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'send_log_details.dart';

/// Gửi THẬT một tin Zalo theo template để kiểm tra cấu hình, xem kết quả ngay.
class ZaloTestScreen extends ConsumerStatefulWidget {
  const ZaloTestScreen({super.key});

  @override
  ConsumerState<ZaloTestScreen> createState() => _ZaloTestScreenState();
}

class _ZaloTestScreenState extends ConsumerState<ZaloTestScreen> {
  final _phone = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _params = {};
  String? _templateKey;
  bool _sending = false;
  bool _refreshing = false;
  SendLogItem? _result;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    for (final c in _params.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectTemplate(ZaloTemplateInfo t) {
    setState(() {
      _templateKey = t.key;
      _result = null;
      for (final c in _params.values) {
        c.dispose();
      }
      _params
        ..clear()
        ..addEntries(t.params.map((p) => MapEntry(p.name, TextEditingController(text: p.sample))));
    });
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate() || _templateKey == null) return;
    setState(() {
      _sending = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await ref.read(adminRepositoryProvider).testSend(
            phone: _phone.text,
            templateKey: _templateKey!,
            data: {for (final e in _params.entries) e.key: e.value.text},
          );
      unawaited(HapticFeedback.lightImpact());
      setState(() => _result = result);
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refreshToken() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(adminRepositoryProvider).refreshZaloToken();
      ref.invalidate(zaloStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã làm mới access token Zalo.')));
      }
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(zaloStatusProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Gửi thử Zalo')),
      body: status.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(zaloStatusProvider)),
        data: (s) {
          final template = s.templates.where((t) => t.key == _templateKey).firstOrNull;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (s.isDevelopment)
                  const InfoNote(
                    'Backend đang ở chế độ development: Zalo chỉ gửi tới số của quản trị viên ứng dụng/OA. '
                    'Đổi ZALO_ZNS_MODE=production trong .env của backend để gửi tới mọi người.',
                    icon: Icons.science_outlined,
                  )
                else
                  const InfoNote(
                    'Chế độ production: tin gửi thật và tính phí theo ZBS Account.',
                    icon: Icons.payments_outlined,
                  ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(
                      s.token.valid ? Icons.vpn_key_rounded : Icons.key_off_rounded,
                      color: s.token.valid ? theme.colorScheme.primary : theme.colorScheme.error,
                    ),
                    title: Text(s.token.valid ? 'Access token còn hiệu lực' : 'Access token chưa sẵn sàng'),
                    subtitle: Text(s.token.expiresAt == null
                        ? 'Backend sẽ tự làm mới khi gửi tin.'
                        : 'Hết hạn lúc ${formatDateTime(s.token.expiresAt!)}'),
                    trailing: TextButton(
                      onPressed: _refreshing ? null : _refreshToken,
                      child: Text(_refreshing ? 'Đang làm mới…' : 'Làm mới'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại nhận',
                    helperText: 'Số phải có tài khoản Zalo. Ví dụ 0912 345 678.',
                  ),
                  validator: VietnamPhone.validate,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _templateKey,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Mẫu tin (template)'),
                  validator: (v) => v == null ? 'Chọn mẫu tin.' : null,
                  items: [
                    for (final t in s.templates)
                      DropdownMenuItem(
                        value: t.key,
                        child: Text(t.configured ? t.title : '${t.title} (chưa cấu hình)'),
                      ),
                  ],
                  onChanged: (key) {
                    final t = s.templates.firstWhere((e) => e.key == key);
                    _selectTemplate(t);
                  },
                ),
                if (template != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    template.configured
                        ? 'Template ID: ${template.templateId}'
                        : 'Chưa có template ID. Điền ${template.envVar} trong .env của backend.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: template.configured ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Tham số', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final p in template.params)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _params[p.name],
                        maxLength: p.maxLength,
                        decoration: InputDecoration(
                          labelText: '${p.name}: ${p.description}',
                          helperText: 'Loại "${p.typeLabel}", tối đa ${p.maxLength} ký tự',
                        ),
                      ),
                    ),
                ],
                if (_error != null) ...[const SizedBox(height: 4), InlineError(_error!)],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Đang gửi…' : 'Gửi tin thật'),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  Text('Kết quả', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SendLogDetails(item: _result!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
