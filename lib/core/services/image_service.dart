import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_core/campus_core.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../config/server_url.dart';
import '../firebase/firebase_providers.dart';
import '../network/api_client.dart';

/// Ảnh đã chọn và nén, chờ tải lên.
class PickedImage {
  const PickedImage(this.bytes);

  final Uint8List bytes;
}

class ImageException implements Exception {
  const ImageException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class ImageService {
  /// Chụp/chọn ảnh rồi nén (JPEG, bỏ EXIF để không lộ vị trí trong ảnh, tối đa 700 KB).
  /// Trả về null nếu người dùng huỷ.
  Future<PickedImage?> pick({required bool fromCamera});

  /// Tải ảnh lên, trả về đường dẫn `report_images/<id>.jpg` để gắn vào báo cáo.
  Future<String> upload(PickedImage image, {required String uploaderUid});

  /// Link hiển thị ảnh.
  Future<String> downloadUrl(String path);
}

/// Ảnh gửi qua backend và lưu trong Firestore, nên mọi máy (dù chạy backend nào) đều xem được và
/// không cần Firebase Storage (gói trả phí).
class BackendImageService implements ImageService {
  BackendImageService(this._api, this._serverUrl, {ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ApiClient _api;
  final String Function() _serverUrl;
  final ImagePicker _picker;

  /// Lần nén sau nhỏ dần cho tới khi vừa giới hạn lưu trữ.
  static const _steps = [(1600, 72), (1280, 65), (1024, 55), (800, 50)];

  @override
  Future<PickedImage?> pick({required bool fromCamera}) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(source: fromCamera ? ImageSource.camera : ImageSource.gallery);
    } on Object {
      throw ImageException(fromCamera
          ? 'Không mở được máy ảnh. Kiểm tra quyền máy ảnh của ứng dụng.'
          : 'Không mở được thư viện ảnh.');
    }
    if (file == null) return null;
    for (final (side, quality) in _steps) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: side,
        minHeight: side,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (compressed == null || compressed.isEmpty) {
        throw const ImageException('Không đọc được ảnh này. Hãy chọn ảnh khác.');
      }
      if (compressed.lengthInBytes <= ReportLimits.maxStoredImageBytes) return PickedImage(compressed);
    }
    throw const ImageException('Ảnh quá lớn kể cả sau khi nén. Hãy chọn ảnh khác.');
  }

  @override
  Future<String> upload(PickedImage image, {required String uploaderUid}) async {
    final res = await _api.post('/images', {'data': base64Encode(image.bytes)});
    final path = res['path'];
    if (path is! String) throw const ImageException('Tải ảnh lên thất bại. Thử lại.');
    return path;
  }

  @override
  Future<String> downloadUrl(String path) async {
    final file = path.split('/').last;
    return '${_serverUrl()}/images/${file.replaceAll('.jpg', '')}';
  }
}

final imageServiceProvider = Provider<ImageService>(
  (ref) => BackendImageService(ref.watch(apiClientProvider), () => ref.read(serverUrlProvider)),
);

/// Link hiển thị ảnh theo đường dẫn đã lưu trong báo cáo.
final imageUrlProvider = FutureProvider.family<String, String>(
  (ref, path) {
    ref.watch(serverUrlProvider);
    return ref.watch(imageServiceProvider).downloadUrl(path);
  },
);
