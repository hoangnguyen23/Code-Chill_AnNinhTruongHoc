import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/session.dart';
import '../data/api_report_repository.dart';
import '../domain/report.dart';
import '../domain/report_filter.dart';
import '../domain/report_repository.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ApiReportRepository(ref.watch(apiClientProvider)),
);

final myReportsProvider = StreamProvider<List<ReportSummary>>((ref) {
  if (ref.watch(signedInUserProvider.select((u) => u?.uid)) == null) return Stream.value(const []);
  return ref.watch(reportRepositoryProvider).watchMyReports();
});

/// Một lần tải chi tiết dùng chung cho ba provider bên dưới.
final reportDetailProvider = StreamProvider.autoDispose.family<ReportDetail, String>(
  (ref, id) => ref.watch(reportRepositoryProvider).watchDetail(id),
);

final reportProvider = Provider.autoDispose.family<AsyncValue<Report?>, String>(
  (ref, id) => ref.watch(reportDetailProvider(id)).whenData((d) => d.report),
);

final reportEventsProvider = Provider.autoDispose.family<AsyncValue<List<ReportEventItem>>, String>(
  (ref, id) => ref.watch(reportDetailProvider(id)).whenData((d) => d.events),
);

final reporterContactProvider = Provider.autoDispose.family<AsyncValue<ReporterContact?>, String>(
  (ref, id) => ref.watch(reportDetailProvider(id)).whenData((d) => d.contact),
);

final openReportsProvider = StreamProvider.autoDispose<List<Report>>(
  (ref) => ref.watch(reportRepositoryProvider).watchOpenReports(),
);

final reportsSinceProvider = StreamProvider.autoDispose.family<List<Report>, TimeRange>(
  (ref, range) => ref.watch(reportRepositoryProvider).watchReportsSince(range.start(DateTime.now())),
);

final assignedToMeProvider = StreamProvider.autoDispose<List<Report>>((ref) {
  if (ref.watch(signedInUserProvider.select((u) => u?.uid)) == null) return Stream.value(const []);
  return ref.watch(reportRepositoryProvider).watchAssignedToMe();
});
