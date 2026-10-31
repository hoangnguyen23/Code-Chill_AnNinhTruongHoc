import 'package:campus_core/campus_core.dart';
import 'package:campus_safety_backend/backend.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  late TestClock clock;
  late MemoryOtpStore store;
  late MemoryUserRepository users;
  late MemoryCredentialRepository credentials;
  late RecordingOtpMailer mailer;
  late FakeAuthTokens auth;

  AccountService service({bool allowSelf = true, Set<String> admins = const {}}) => AccountService(
        store: store,
        users: users,
        credentials: credentials,
        mailer: mailer,
        auth: auth,
        pepper: 'p' * 40,
        allowSelfRegistration: allowSelf,
        bootstrapAdmins: admins.map(EmailAddress.parse).toSet(),
        hasher: PasswordHasher(iterations: 10),
        clock: clock.call,
      );

  setUp(() {
    clock = TestClock(DateTime.utc(2026, 10, 25, 12));
    store = MemoryOtpStore();
    users = MemoryUserRepository();
    credentials = MemoryCredentialRepository();
    mailer = RecordingOtpMailer();
    auth = FakeAuthTokens();
  });

  String lastCode() => mailer.sent.last.$2;

  TypeMatcher<ApiException> apiError(String code, {int? status}) => isA<ApiException>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.statusCode, 'status', status ?? anything);

  const email = 'khoa.tran@gmail.com';
  RegistrationInput input({
    String username = 'khoa.tran',
    String password = 'matkhau123',
    String mail = email,
    String memberType = 'student',
  }) =>
      RegistrationInput(
        email: mail,
        username: username,
        password: password,
        displayName: 'Trần Minh Khoa',
        memberType: memberType,
      );

  group('Đăng ký', () {
    test('gửi OTP trước, chỉ tạo tài khoản khi nhập đúng mã', () async {
      final svc = service();
      final res = await svc.requestRegistration(input(username: '  Khoa.Tran '), ip: '1');
      expect(res.toJson()['emailMasked'], 'kh***@gmail.com');
      expect(mailer.sent.single.$1.value, email);
      expect(users.byUid, isEmpty, reason: 'chưa nhập mã thì chưa có tài khoản');
      final pending = store.data.values.single.pending;
      expect(pending['username'], 'khoa.tran');
      expect(pending['passwordHash'], startsWith('pbkdf2_sha256\$'));
      expect(pending.values.join(), isNot(contains('matkhau123')), reason: 'không lưu mật khẩu gốc');

      final signed = await svc.verifyRegistration(email, lastCode(), ip: '1');
      expect(signed.isNewUser, isTrue);
      expect(signed.user.username, 'khoa.tran');
      expect(signed.user.displayName, 'Trần Minh Khoa');
      expect(signed.user.role, UserRole.reporter);
      expect(signed.user.memberType, MemberType.student);
      expect(credentials.byUidMap[signed.user.uid]!.username, 'khoa.tran');
      expect(auth.issued[signed.user.uid], {'role': 'reporter'});
    });

    test('nhập sai OTP: không tạo tài khoản, báo số lần còn lại', () async {
      final svc = service();
      await svc.requestRegistration(input(), ip: '1');
      final wrong = lastCode() == '000000' ? '111111' : '000000';
      await expectLater(
        svc.verifyRegistration(email, wrong, ip: '1'),
        throwsA(apiError('otp_wrong').having((e) => e.message, 'message', contains('còn 4 lần'))),
      );
      expect(users.byUid, isEmpty);
      expect(credentials.byUidMap, isEmpty);
    });

    test('mã hết hạn sau 5 phút và chỉ dùng một lần', () async {
      final svc = service();
      await svc.requestRegistration(input(), ip: '1');
      clock.advance(const Duration(minutes: 5, seconds: 1));
      await expectLater(svc.verifyRegistration(email, lastCode(), ip: '1'), throwsA(apiError('otp_expired')));

      clock.advance(const Duration(minutes: 1));
      await svc.requestRegistration(input(), ip: '1');
      final code = lastCode();
      await svc.verifyRegistration(email, code, ip: '1');
      await expectLater(svc.verifyRegistration(email, code, ip: '1'), throwsA(apiError('otp_invalid')));
    });

    test('không gửi lựa chọn thì mặc định Sinh viên', () async {
      final svc = service();
      await svc.requestRegistration(input(memberType: ''), ip: '1');
      final res = await svc.verifyRegistration(email, lastCode(), ip: '1');
      expect(res.user.memberType, MemberType.student);
      expect(mailer.actions.single, 'đăng ký tài khoản');
    });

    test('chỉ được tự chọn Sinh viên hoặc Giảng viên, vai trò luôn là người báo', () async {
      final svc = service();
      for (final bad in ['staff', 'other', 'admin']) {
        await expectLater(
          svc.requestRegistration(input(memberType: bad), ip: 'm$bad'),
          throwsA(isA<ApiException>().having((e) => (e.details!['fields']! as Map).keys, 'fields', contains('memberType'))),
          reason: bad,
        );
      }
      await svc.requestRegistration(input(memberType: 'lecturer'), ip: '1');
      final res = await svc.verifyRegistration(email, lastCode(), ip: '1');
      expect(res.user.memberType, MemberType.lecturer);
      expect(res.user.role, UserRole.reporter);
    });

    test('kiểm tra tên đăng nhập, mật khẩu, họ tên trước khi gửi mã', () async {
      await expectLater(
        service().requestRegistration(input(username: '1a', password: 'ngan'), ip: '1'),
        throwsA(isA<ApiException>().having(
          (e) => (e.details!['fields']! as Map).keys,
          'fields',
          containsAll(['username', 'password']),
        )),
      );
      expect(mailer.sent, isEmpty);
    });

    test('tên đăng nhập trùng hoặc email đã đăng ký thì báo lỗi', () async {
      final svc = service();
      await svc.requestRegistration(input(), ip: '1');
      await svc.verifyRegistration(email, lastCode(), ip: '1');
      await expectLater(
        svc.requestRegistration(input(mail: 'khac@gmail.com'), ip: '2'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('đã có người dùng'))),
      );
      await expectLater(
        svc.requestRegistration(input(username: 'ten.khac'), ip: '3'),
        throwsA(apiError('email_registered', status: 409)),
      );
    });

    test('email quản trị khởi tạo thành quản trị; email lạ bị chặn khi tắt tự đăng ký', () async {
      final svc = service(allowSelf: false, admins: {'admin@truong.edu.vn'});
      await expectLater(svc.requestRegistration(input(), ip: '1'), throwsA(apiError('forbidden', status: 403)));
      await svc.requestRegistration(input(mail: 'Admin@Truong.edu.vn', username: 'quantri'), ip: '1');
      final res = await svc.verifyRegistration('admin@truong.edu.vn', lastCode(), ip: '1');
      expect(res.user.role, UserRole.admin);
    });

    test('nhận tài khoản quản trị tạo trước: giữ vai trò bảo vệ, thêm tên đăng nhập', () async {
      final guard = users.seed(email: 'baove@truong.edu.vn', name: 'Lê Văn Hùng', role: UserRole.guard);
      final svc = service(allowSelf: false);
      await svc.requestRegistration(input(mail: guard.email.value, username: 'hung.bv'), ip: '1');
      final res = await svc.verifyRegistration(guard.email.value, lastCode(), ip: '1');
      expect(res.user.uid, guard.uid);
      expect(res.user.role, UserRole.guard);
      expect(res.user.displayName, 'Lê Văn Hùng', reason: 'giữ tên quản trị đã nhập');
      expect(res.user.memberType, guard.memberType, reason: 'giữ đối tượng quản trị đã gán');
      expect(res.isNewUser, isFalse);
    });

    test('gửi mail lỗi: báo 503, mã không dùng được', () async {
      mailer.failWith = const OtpMailException('Không kết nối được máy chủ gửi mail. Thử lại sau ít phút.');
      await expectLater(
        service().requestRegistration(input(), ip: '1'),
        throwsA(apiError('email_send_failed', status: 503)),
      );
      expect(store.data.values.single.hasActiveCode, isFalse);
    });

    test('giới hạn gửi lại mã 60 giây', () async {
      final svc = service();
      await svc.requestRegistration(input(), ip: '1');
      await expectLater(svc.requestRegistration(input(), ip: '1'), throwsA(apiError('otp_cooldown', status: 429)));
    });
  });

  group('Đăng nhập', () {
    late AccountService svc;

    setUp(() async {
      svc = service();
      await svc.requestRegistration(input(), ip: 'r');
      await svc.verifyRegistration(email, lastCode(), ip: 'r');
    });

    test('đúng tên đăng nhập (không phân biệt hoa thường) hoặc email + mật khẩu', () async {
      final a = await svc.login('Khoa.Tran', 'matkhau123', ip: '1');
      expect(a.customToken, startsWith('custom-token-'));
      final b = await svc.login(' KHOA.TRAN@gmail.com ', 'matkhau123', ip: '1');
      expect(b.user.uid, a.user.uid);
    });

    test('sai mật khẩu: báo chung chung, sai 5 lần thì khoá 15 phút', () async {
      await expectLater(
        svc.login('khoa.tran', 'sai12345', ip: '1'),
        throwsA(apiError('invalid_credentials', status: 401)
            .having((e) => e.message, 'm', 'Tên đăng nhập hoặc mật khẩu không đúng.')),
      );
      for (var i = 0; i < 3; i++) {
        await expectLater(svc.login('khoa.tran', 'sai12345', ip: '1'), throwsA(apiError('invalid_credentials')));
      }
      await expectLater(svc.login('khoa.tran', 'sai12345', ip: '1'), throwsA(apiError('login_locked', status: 429)));
      await expectLater(svc.login('khoa.tran', 'matkhau123', ip: '1'), throwsA(apiError('login_locked')));
      clock.advance(const Duration(minutes: 16));
      final ok = await svc.login('khoa.tran', 'matkhau123', ip: '1');
      expect(ok.user.username, 'khoa.tran');
      expect(credentials.byUidMap[ok.user.uid]!.failedAttempts, 0);
    });

    test('sai mật khẩu lần 1 đến 4: phản hồi y hệt tên không tồn tại (không lộ tài khoản)', () async {
      Future<(int, String, String)> attempt(String name) async {
        try {
          await svc.login(name, 'sai12345', ip: '1');
        } on ApiException catch (e) {
          return (e.statusCode, e.code, e.message);
        }
        fail('phải báo lỗi');
      }

      for (var i = 0; i < LoginPolicy.maxFailures - 1; i++) {
        expect(await attempt('khoa.tran'), await attempt('khong.co'), reason: 'lần sai thứ ${i + 1}');
      }
    });

    test('tên không tồn tại báo giống sai mật khẩu', () async {
      await expectLater(
        svc.login('khong.co', 'matkhau123', ip: '1'),
        throwsA(apiError('invalid_credentials').having((e) => e.message, 'm', 'Tên đăng nhập hoặc mật khẩu không đúng.')),
      );
    });

    test('tài khoản bị khoá không đăng nhập được', () async {
      final uid = credentials.byUidMap.keys.single;
      await users.update(uid, active: false);
      await expectLater(svc.login('khoa.tran', 'matkhau123', ip: '1'), throwsA(apiError('forbidden')));
    });

    test('thiếu thông tin', () async {
      await expectLater(svc.login('', '', ip: '1'), throwsA(apiError('validation_failed')));
    });
  });

  test('băm mật khẩu: đúng chuẩn PBKDF2, muối khác nhau mỗi lần', () {
    final h = PasswordHasher(iterations: 1000);
    final a = h.hash('matkhau123');
    expect(a, isNot(h.hash('matkhau123')));
    expect(h.verify('matkhau123', a), isTrue);
    expect(h.verify('matkhau124', a), isFalse);
    expect(h.verify('matkhau123', 'rac'), isFalse);
    // Vector kiểm thử RFC 7914 mục 11 (PBKDF2-HMAC-SHA256, P="passwd", S="salt", c=1).
    expect(
      PasswordHasher().verify('passwd', r'pbkdf2_sha256$1$c2FsdA==$VawEblbjCJ/sFpHCJUS2BflBhSFt3gRl5oudV8INrLw='),
      isTrue,
    );
  });

  group('Quên mật khẩu', () {
    late AccountService svc;

    setUp(() async {
      svc = service(admins: {'admin@truong.edu.vn'});
      await svc.requestRegistration(input(), ip: 'r');
      await svc.verifyRegistration(email, lastCode(), ip: 'r');
      clock.advance(const Duration(minutes: 2));
    });

    test('nhập đúng OTP thì đổi được mật khẩu, mật khẩu cũ hết dùng được', () async {
      final res = await svc.requestPasswordReset(' KHOA.TRAN@gmail.com ', ip: '1');
      expect(res.toJson()['emailMasked'], 'kh***@gmail.com');
      expect(mailer.actions.last, 'đặt lại mật khẩu');
      final signed = await svc.resetPassword(email, lastCode(), 'matkhaumoi9', ip: '1');
      expect(signed.customToken, startsWith('custom-token-'));
      expect(auth.revoked, contains(signed.user.uid), reason: 'đăng xuất các máy dùng mật khẩu cũ');
      await expectLater(svc.login('khoa.tran', 'matkhau123', ip: '1'), throwsA(apiError('invalid_credentials')));
      expect((await svc.login('khoa.tran', 'matkhaumoi9', ip: '1')).user.email.value, email);
    });

    test('sai OTP thì không đổi mật khẩu', () async {
      await svc.requestPasswordReset(email, ip: '1');
      final wrong = lastCode() == '000000' ? '111111' : '000000';
      await expectLater(svc.resetPassword(email, wrong, 'matkhaumoi9', ip: '1'), throwsA(apiError('otp_wrong')));
      expect((await svc.login('khoa.tran', 'matkhau123', ip: '1')).user.username, 'khoa.tran');
    });

    test('email chưa đăng ký: báo lỗi, không gửi mail', () async {
      final before = mailer.sent.length;
      await expectLater(
        svc.requestPasswordReset('chua.co@gmail.com', ip: '1'),
        throwsA(isA<ApiException>().having((e) => e.message, 'm', contains('chưa đăng ký'))),
      );
      expect(mailer.sent, hasLength(before));
    });

    test('mật khẩu mới phải đạt yêu cầu; mã đặt lại không dùng để đăng ký và ngược lại', () async {
      await svc.requestPasswordReset(email, ip: '1');
      await expectLater(svc.resetPassword(email, lastCode(), 'ngan', ip: '1'), throwsA(apiError('validation_failed')));
      await expectLater(svc.verifyRegistration(email, lastCode(), ip: '1'), throwsA(apiError('otp_invalid')));
    });

    test('đặt lại mật khẩu mở khoá tài khoản đang bị khoá do sai nhiều lần', () async {
      for (var i = 0; i < 5; i++) {
        await expectLater(svc.login('khoa.tran', 'sai12345', ip: 'x$i'), throwsA(isA<ApiException>()));
      }
      await expectLater(svc.login('khoa.tran', 'matkhau123', ip: 'y'), throwsA(apiError('login_locked')));
      await svc.requestPasswordReset(email, ip: '1');
      await svc.resetPassword(email, lastCode(), 'matkhaumoi9', ip: '1');
      expect((await svc.login('khoa.tran', 'matkhaumoi9', ip: 'z')).user.username, 'khoa.tran');
    });
  });

  group('Xoá tài khoản', () {
    late AccountService svc;
    late UserRecord admin;

    setUp(() async {
      svc = service(admins: {'admin@truong.edu.vn'});
      await svc.requestRegistration(input(mail: 'admin@truong.edu.vn', username: 'quantri'), ip: 'a');
      admin = (await svc.verifyRegistration('admin@truong.edu.vn', lastCode(), ip: 'a')).user;
      await svc.requestRegistration(input(), ip: 'b');
      await svc.verifyRegistration(email, lastCode(), ip: 'b');
    });

    test('quản trị xoá tài khoản: mất hồ sơ, tên đăng nhập, mật khẩu; tên đăng nhập dùng lại được', () async {
      final target = (await users.byEmail(EmailAddress.parse(email)))!;
      await svc.deleteAccount(admin, target.uid);
      expect(await users.byId(target.uid), isNull);
      expect(credentials.byUidMap.containsKey(target.uid), isFalse);
      expect(auth.deleted, [target.uid]);
      expect(auth.revoked, contains(target.uid));
      await expectLater(svc.login('khoa.tran', 'matkhau123', ip: '1'), throwsA(apiError('invalid_credentials')));
      clock.advance(const Duration(minutes: 2));
      await svc.requestRegistration(input(), ip: 'c');
      expect((await svc.verifyRegistration(email, lastCode(), ip: 'c')).isNewUser, isTrue);
    });

    test('không tự xoá mình, không xoá quản trị gốc, người không phải quản trị không xoá được', () async {
      final target = (await users.byEmail(EmailAddress.parse(email)))!;
      await expectLater(svc.deleteAccount(admin, admin.uid), throwsA(apiError('forbidden')));
      await expectLater(svc.deleteAccount(target, admin.uid), throwsA(apiError('forbidden')));
      final otherAdmin = users.seed(email: 'phu@truong.edu.vn', role: UserRole.admin);
      await expectLater(
        svc.deleteAccount(otherAdmin, admin.uid),
        throwsA(isA<ApiException>().having((e) => e.message, 'm', contains('quản trị gốc'))),
      );
      await expectLater(svc.deleteAccount(admin, 'khong-co'), throwsA(apiError('not_found')));
    });
  });

  group('Đổi mật khẩu', () {
    late AccountService svc;
    late UserRecord me;

    setUp(() async {
      svc = service();
      await svc.requestRegistration(input(), ip: 'r');
      me = (await svc.verifyRegistration(email, lastCode(), ip: 'r')).user;
    });

    test('đúng mật khẩu hiện tại thì đổi được', () async {
      await svc.changePassword(me, 'matkhau123', 'matkhaumoi9');
      expect((await svc.login('khoa.tran', 'matkhaumoi9', ip: '1')).user.uid, me.uid);
      await expectLater(svc.login('khoa.tran', 'matkhau123', ip: '1'), throwsA(apiError('invalid_credentials')));
    });

    test('sai mật khẩu hiện tại, mật khẩu mới yếu hoặc trùng cũ thì từ chối', () async {
      Matcher field(String f) =>
          throwsA(isA<ApiException>().having((e) => (e.details!['fields']! as Map).keys, 'fields', contains(f)));
      await expectLater(svc.changePassword(me, 'sai12345', 'matkhaumoi9'), field('currentPassword'));
      await expectLater(svc.changePassword(me, 'matkhau123', 'ngan'), field('newPassword'));
      await expectLater(svc.changePassword(me, 'matkhau123', 'matkhau123'), field('newPassword'));
      expect((await svc.login('khoa.tran', 'matkhau123', ip: '1')).user.uid, me.uid);
    });
  });
}
