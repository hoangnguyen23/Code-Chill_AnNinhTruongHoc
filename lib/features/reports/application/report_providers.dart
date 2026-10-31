import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/session.dart';
import '../data/firestore_report_repository.dart';
import '../domain/report.dart';
import '../domain/report_filter.dart';
import '../domain/report_repository.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => FirestoreReportRepository(ref.watch(firestoreProvider), ref.watch(apiClientProvider)),
);

final myReportsProvider = StreamProvider<List<ReportSummary>>((ref) {
  final uid = ref.watch(signedInUserProvider)?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(reportRepositoryProvider).watchMyReports(uid);
});

final reportProvider = StreamProvider.autoDispose.family<Report?, String>(
  (ref, id) => ref.watch(reportRepositoryProvider).watchReport(id),
);

final reportEventsProvider = StreamProvider.autoDispose.family<List<ReportEventItem>, String>(
  (ref, id) => ref.watch(reportRepositoryProvider).watchEvents(id),
);

final reporterContactProvider = StreamProvider.autoDispose.family<ReporterContact?, String>(
  (ref, id) => ref.watch(reportRepositoryProvider).watchReporterContact(id),
);

final openReportsProvider = StreamProvider.autoDispose<List<Report>>(
  (ref) => ref.watch(reportRepositoryProvider).watchOpenReports(),
);

final reportsSinceProvider = StreamProvider.autoDispose.family<List<Report>, TimeRange>(
  (ref, range) => ref.watch(reportRepositoryProvider).watchReportsSince(range.start(DateTime.now())),
);

final assignedToMeProvider = StreamProvider.autoDispose<List<Report>>((ref) {
  final uid = ref.watch(signedInUserProvider)?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(reportRepositoryProvider).watchAssignedTo(uid);
});
