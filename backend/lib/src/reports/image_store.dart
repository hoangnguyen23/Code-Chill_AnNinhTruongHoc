import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:campus_core/campus_core.dart';
import 'package:dart_firebase_admin/firestore.dart';

import '../data/firestore_repositories.dart';
import '../data/models.dart';
import '../http/api_exception.dart';

/// Kho ảnh sự cố. Lưu trong Firestore (`report_images/{id}`) để mọi backend dùng chung mà không
/// cần Firebase Storage (Storage đòi gói trả phí Blaze).
abstract interface class ImageRepository {
  Future<void> save(String id, {required String uploaderUid, required Uint8List bytes});

  Future<Uint8List?> load(String id);
}

class FirestoreImageRepository implements ImageRepository {
  FirestoreImageRepository(this._db);

  final Firestore _db;

  DocumentReference<DocumentData> _ref(String id) => _db.doc('${Collections.reportImages}/$id');

  @override
  Future<void> save(String id, {required String uploaderUid, required Uint8List bytes}) async {
    await _ref(id).set({
      'data': base64Encode(bytes),
      'contentType': 'image/jpeg',
      'size': bytes.length,
      'uploaderUid': uploaderUid,
      'createdAt': DateTime.now().toUtc(),
    });
  }

  @override
  Future<Uint8List?> load(String id) async {
    final data = (await _ref(id).get()).data()?['data'];
    return data is String ? base64Decode(data) : null;
  }
}

/// Nhận ảnh JPEG đã nén từ app, trả về đường dẫn `report_images/<id>.jpg` để gắn vào báo cáo.
///
/// ID ngẫu nhiên 32 ký tự (không đoán được) nên link xem ảnh `GET /images/<id>` không cần đăng nhập,
/// giống link tải có token của Firebase Storage; chỉ người xem được báo cáo mới biết link.
class ImageService {
  ImageService(this._images, {Random? random}) : _random = random ?? Random.secure();

  final ImageRepository _images;
  final Random _random;

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static final idPattern = RegExp(r'^[A-Za-z0-9]{32}$');

  Future<String> upload(UserRecord user, String base64Data) async {
    final Uint8List bytes;
    try {
      bytes = base64Decode(base64Data.trim());
    } on FormatException {
      throw ApiException.validation({'image': 'Dữ liệu ảnh không hợp lệ.'});
    }
    if (bytes.isEmpty) throw ApiException.validation({'image': 'Ảnh trống.'});
    if (bytes.length > ReportLimits.maxStoredImageBytes) {
      throw ApiException.validation({'image': 'Ảnh quá lớn (tối đa 700 KB sau khi nén). Hãy chọn ảnh khác.'});
    }
    // JPEG bắt đầu bằng FF D8 FF.
    if (bytes.length < 3 || bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) {
      throw ApiException.validation({'image': 'Chỉ nhận ảnh JPEG.'});
    }
    final id = List.generate(32, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();
    await _images.save(id, uploaderUid: user.uid, bytes: bytes);
    return 'report_images/$id.jpg';
  }

  Future<Uint8List?> load(String id) => idPattern.hasMatch(id) ? _images.load(id) : Future.value();
}
