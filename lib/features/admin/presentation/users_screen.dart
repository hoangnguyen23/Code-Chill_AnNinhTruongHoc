import 'package:campus_core/campus_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/profile_setup_screen.dart' show validateOptionalPhone;
import '../../auth/application/session.dart';
import '../../auth/domain/app_user.dart';
import '../data/admin_repository.dart';

class _RoleTab extends Notifier<UserRole> {
  @override
  UserRole build() => UserRole.guard;

  void set(UserRole r) => state = r;
}

final _roleTabProvider = NotifierProvider<_RoleTab, UserRole>(_RoleTab.new);

/// Quản lý tài khoản: danh sách theo vai trò, tìm kiếm, tạo trước, phân quyền, khoá.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(AppUser u, String q) {
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return u.displayName.toLowerCase().contains(q.toLowerCase()) ||
        u.email.contains(q.toLowerCase()) ||
        (digits.length >= 3 && u.phone.contains(digits.startsWith('84') ? '0${digits.substring(2)}' : digits));
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(_roleTabProvider);
    final users = ref.watch(usersByRoleProvider(role));
    final me = ref.watch(signedInUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => UserFormSheet(initialRole: role),
        ),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Thêm tài khoản'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(value: UserRole.guard, label: Text('Bảo vệ')),
                  ButtonSegment(value: UserRole.admin, label: Text('Quản trị')),
                  ButtonSegment(value: UserRole.reporter, label: Text('Người báo')),
                ],
                selected: {role},
                onSelectionChanged: (v) => ref.read(_roleTabProvider.notifier).set(v.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Tìm theo tên, email hoặc số điện thoại',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xoá tìm kiếm',
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const SkeletonList(),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(usersByRoleProvider(role))),
              data: (list) {
                final filtered = list.where((u) => _matches(u, _search.text.trim())).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.person_search_outlined,
                    title: list.isEmpty ? 'Chưa có tài khoản ${role.label.toLowerCase()}' : 'Không tìm thấy',
                    message: list.isEmpty ? 'Bấm "Thêm tài khoản" để tạo.' : 'Thử từ khoá khác.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = filtered[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          !u.active
                              ? Icons.lock_outline_rounded
                              : u.onDuty
                                  ? Icons.shield_rounded
                                  : Icons.person_outline_rounded,
                        ),
                        title: Text(u.profileComplete ? u.displayName : 'Chưa có tên'),
                        subtitle: Text([
                          if (u.username.isEmpty) 'Chưa kích hoạt' else '@${u.username}',
                          u.email,
                          if (u.hasPhone) u.phoneDisplay,
                          if (!u.active) 'Đã khoá',
                          if (u.onDuty) 'Đang trực',
                          if (u.uid == me?.uid) 'Bạn',
                        ].join(', ')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => UserFormSheet(existing: u, isSelf: u.uid == me?.uid),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tạo mới hoặc sửa tài khoản.
class UserFormSheet extends ConsumerStatefulWidget {
  const UserFormSheet({super.key, this.existing, this.initialRole = UserRole.guard, this.isSelf = false});

  final AppUser? existing;
  final UserRole initialRole;
  final bool isSelf;

  @override
  ConsumerState<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends ConsumerState<UserFormSheet> {
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _name = TextEditingController(text: widget.existing?.displayName ?? '');
  late UserRole _role = widget.existing?.role ?? widget.initialRole;
  late bool _active = widget.existing?.active ?? true;
  late bool _onDuty = widget.existing?.onDuty ?? false;
  late MemberType _memberType = widget.existing?.memberType ?? MemberType.staff;
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(adminRepositoryProvider);
    try {
      if (_isNew) {
        await repo.createUser(
          email: _email.text,
          phone: _phone.text,
          displayName: _name.text.trim(),
          role: _role,
          memberType: _memberType,
          onDuty: _role.isStaff && _onDuty,
        );
      } else {
        final e = widget.existing!;
        await repo.updateUser(
          e.uid,
          displayName: _name.text.trim() != e.displayName ? _name.text.trim() : null,
          role: _role != e.role ? _role : null,
          active: _active != e.active ? _active : null,
          onDuty: _onDuty != e.onDuty ? (_role.isStaff && _onDuty) : null,
          memberType: _memberType != e.memberType ? _memberType : null,
        );
      }
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.existing!;
    final who = e.profileComplete ? e.displayName : e.email;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded),
        title: const Text('Xoá tài khoản?'),
        content: Text(
          'Xoá vĩnh viễn tài khoản "$who" (${e.email}). Người này không đăng nhập được nữa và phải đăng ký lại. '
          'Các báo cáo họ đã gửi vẫn được giữ.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).deleteUser(e.uid);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text('Đã xoá tài khoản $who.')));
      }
    } on ApiError catch (err) {
      setState(() => _error = err.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isNew ? 'Thêm tài khoản' : 'Sửa tài khoản', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                enabled: _isNew,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: _isNew
                      ? 'Người này bấm "Đăng ký ngay" bằng đúng email này để đặt tên đăng nhập và mật khẩu; '
                          'vai trò bạn chọn được giữ nguyên.'
                      : null,
                ),
                validator: _isNew ? EmailAddress.validate : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                enabled: _isNew,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                decoration: InputDecoration(
                  labelText: 'Số điện thoại (không bắt buộc)',
                  helperText: _isNew ? 'Để bảo vệ liên hệ khi cần.' : null,
                ),
                validator: _isNew ? validateOptionalPhone : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Họ tên'),
                validator: ProfileLimits.validateDisplayName,
              ),
              const SizedBox(height: 16),
              Text('Vai trò', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<UserRole>(
                segments: [
                  for (final r in UserRole.values)
                    ButtonSegment(value: r, label: Text(r.label), enabled: !widget.isSelf || r == UserRole.admin),
                ],
                selected: {_role},
                onSelectionChanged: (v) => setState(() => _role = v.first),
              ),
              if (_role == UserRole.reporter) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<MemberType>(
                  initialValue: _memberType,
                  decoration: const InputDecoration(labelText: 'Đối tượng'),
                  items: [for (final m in MemberType.values) DropdownMenuItem(value: m, child: Text(m.label))],
                  onChanged: (v) => setState(() => _memberType = v ?? _memberType),
                ),
              ],
              if (_role.isStaff)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _onDuty,
                  onChanged: (v) => setState(() => _onDuty = v),
                  title: const Text('Đang trực'),
                  subtitle: const Text('Nhận cảnh báo khi có sự cố mới.'),
                ),
              if (!_isNew)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: widget.isSelf ? null : (v) => setState(() => _active = v),
                  title: const Text('Cho phép đăng nhập'),
                  subtitle: Text(widget.isSelf
                      ? 'Bạn không thể tự khoá tài khoản của mình.'
                      : 'Tắt để khoá tài khoản và đăng xuất khỏi mọi thiết bị.'),
                ),
              if (_error != null) ...[const SizedBox(height: 12), InlineError(_error!)],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Đang lưu…' : (_isNew ? 'Tạo tài khoản' : 'Lưu thay đổi')),
              ),
              if (!_isNew && !widget.isSelf) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Xoá tài khoản'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
