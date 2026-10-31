import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/server_url.dart';
import '../../../core/widgets/state_views.dart';
import '../../campus/campus_info.dart';

Future<void> showServerUrlDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ServerUrlDialog());

/// Đổi địa chỉ backend (ví dụ IP Wi-Fi của laptop chạy backend) và kiểm tra kết nối.
class _ServerUrlDialog extends ConsumerStatefulWidget {
  const _ServerUrlDialog();

  @override
  ConsumerState<_ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends ConsumerState<_ServerUrlDialog> {
  late final _url = TextEditingController(text: ref.read(serverUrlProvider));
  bool _checking = false;
  String? _result;
  bool _ok = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final url = normalizeServerUrl(_url.text);
    if (url == null) {
      setState(() {
        _ok = false;
        _result = 'Địa chỉ không hợp lệ. Ví dụ: 192.168.1.10:8080';
      });
      return;
    }
    setState(() {
      _checking = true;
      _result = null;
    });
    try {
      final res = await http.get(Uri.parse('$url/')).timeout(const Duration(seconds: 6));
      final body = jsonDecode(res.body);
      _ok = res.statusCode == 200 && body is Map && body['ok'] == true;
      _result = _ok ? 'Kết nối được máy chủ.' : 'Địa chỉ này không phải máy chủ của ứng dụng.';
    } on TimeoutException {
      _ok = false;
      _result = 'Không phản hồi. Kiểm tra laptop đã chạy backend, cùng Wi-Fi và tường lửa cho phép cổng 8080.';
    } on Object {
      _ok = false;
      _result = 'Không kết nối được. Kiểm tra lại địa chỉ IP và mạng Wi-Fi.';
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save(String value) async {
    await ref.read(serverUrlProvider.notifier).set(value);
    ref.invalidate(campusInfoProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Địa chỉ máy chủ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nhập IP Wi-Fi của máy tính đang chạy backend. Các điện thoại phải bắt cùng mạng Wi-Fi.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Địa chỉ', hintText: '192.168.1.10:8080'),
              onChanged: (_) => setState(() => _result = null),
            ),
            const SizedBox(height: 8),
            Text(
              'Mặc định: ${AppConfig.apiBaseUrl}',
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              _ok ? InfoNote(_result!, icon: Icons.check_circle_outline_rounded) : InlineError(_result!),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_find_rounded),
              label: const Text('Kiểm tra kết nối'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => _save(''), child: const Text('Dùng mặc định')),
        FilledButton(
          onPressed: () {
            final url = normalizeServerUrl(_url.text);
            if (url == null) {
              setState(() {
                _ok = false;
                _result = 'Địa chỉ không hợp lệ. Ví dụ: 192.168.1.10:8080';
              });
              return;
            }
            _save(url);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
