import 'package:campus_core/campus_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/image_service.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';
import 'report_providers.dart';

/// Gửi báo cáo: tải ảnh đã nén lên Storage, rồi gọi backend tạo báo cáo.
class ReportSubmitter {
  ReportSubmitter(this._reports, this._images);

  final ReportRepository _reports;
  final ImageService _images;

  Future<SubmitReportResult> submit(
    ReportDraft draft, {
    required List<PickedImage> images,
    required String uploaderUid,
    void Function(int uploaded, int total)? onUploadProgress,
  }) async {
    final paths = <String>[];
    for (var i = 0; i < images.length; i++) {
      paths.add(await _images.upload(images[i], uploaderUid: uploaderUid));
      onUploadProgress?.call(i + 1, images.length);
    }
    return _reports.submit(ReportDraft(
      type: draft.type,
      severity: draft.severity,
      description: draft.description.trim(),
      occurredAt: draft.occurredAt,
      building: draft.building,
      floor: draft.floor,
      room: draft.room,
      latitude: draft.latitude,
      longitude: draft.longitude,
      accuracyMeters: draft.accuracyMeters,
      anonymous: draft.anonymous,
      emergency: draft.emergency,
      imagePaths: paths,
    ));
  }
}

final reportSubmitterProvider = Provider<ReportSubmitter>(
  (ref) => ReportSubmitter(ref.watch(reportRepositoryProvider), ref.watch(imageServiceProvider)),
);
