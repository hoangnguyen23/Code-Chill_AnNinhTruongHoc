import 'package:campus_core/campus_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/polling.dart';
import '../../auth/domain/app_user.dart';
import '../../campus/campus_info.dart';

/// Quản trị quản lý tài khoản qua backend (`/admin/*` chỉ quản trị gọi được).
class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  static List<AppUser> _users(Map<String, Object?> j) => [
        for (final u in ((j['users'] as List?) ?? const []).whereType<Map>()) AppUser.fromApi(u.cast<String, Object?>()),
      ]..sort((a, b) => a.nameOrEmail.toLowerCase().compareTo(b.nameOrEmail.toLowerCase()));

  Stream<List<AppUser>> watchUsers(UserRole role) => pollApi(_api, '/admin/users?role=${role.wire}', _users);

  /// Bảo vệ và quản trị (để phân công).
  Stream<List<AppUser>> watchStaff() => pollApi(_api, '/admin/users', _users);

  Future<AppUser> createUser({
    required String email,
    String? phone,
    required String displayName,
    required UserRole role,
    MemberType? memberType,
    bool onDuty = false,
  }) async {
    final res = await _api.post('/admin/users', {
      'email': email,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone,
      'displayName': displayName,
      'role': role.wire,
      if (memberType != null) 'memberType': memberType.wire,
      'onDuty': onDuty,
    });
    return AppUser.fromApi(res['user']! as Map<String, Object?>);
  }

  /// Xoá tài khoản (báo cáo người đó đã gửi vẫn giữ).
  Future<void> deleteUser(String uid) => _api.delete('/admin/users/$uid');

  Future<AppUser> updateUser(
    String uid, {
    UserRole? role,
    bool? active,
    bool? onDuty,
    String? displayName,
    MemberType? memberType,
  }) async {
    final res = await _api.patch('/admin/users/$uid', {
      if (role != null) 'role': role.wire,
      'active': ?active,
      'onDuty': ?onDuty,
      'displayName': ?displayName,
      if (memberType != null) 'memberType': memberType.wire,
    });
    return AppUser.fromApi(res['user']! as Map<String, Object?>);
  }

  Future<void> updateCampus({
    required String campusName,
    required String? hotline,
    required List<String> buildings,
  }) async {
    await _api.put('/admin/config', {
      'campusName': campusName,
      'hotline': hotline ?? '',
      'buildings': buildings,
    });
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

final usersByRoleProvider = StreamProvider.autoDispose.family<List<AppUser>, UserRole>(
  (ref, role) => ref.watch(adminRepositoryProvider).watchUsers(role),
);

final staffProvider = StreamProvider.autoDispose<List<AppUser>>((ref) => ref.watch(adminRepositoryProvider).watchStaff());

/// Làm mới cấu hình trường sau khi quản trị sửa.
void refreshCampus(WidgetRef ref) => ref.invalidate(campusInfoProvider);
