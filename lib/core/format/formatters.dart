/// Định dạng thời gian tiếng Việt theo giờ máy (người dùng ở Việt Nam).
library;

String _two(int v) => v.toString().padLeft(2, '0');

/// `14:05 19/10/2026`
String formatDateTime(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)} ${_two(l.day)}/${_two(l.month)}/${l.year}';
}

/// `19/10/2026`
String formatDate(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.day)}/${_two(l.month)}/${l.year}';
}

/// `14:05`
String formatTime(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// "Vừa xong", "5 phút trước", "3 giờ trước", "Hôm qua 14:05", hoặc ngày đầy đủ.
String formatRelative(DateTime t, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final local = t.toLocal();
  final diff = current.difference(local);
  if (diff.isNegative || diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;
  if (days == 0) return '${diff.inHours} giờ trước';
  if (days == 1) return 'Hôm qua ${formatTime(local)}';
  if (days < 7) return '$days ngày trước';
  return formatDateTime(local);
}

/// "2 giờ 15 phút", "45 phút", "3 ngày 4 giờ".
String formatDuration(Duration d) {
  if (d.inMinutes < 1) return 'dưới 1 phút';
  if (d.inHours < 1) return '${d.inMinutes} phút';
  if (d.inDays < 1) {
    final m = d.inMinutes % 60;
    return m == 0 ? '${d.inHours} giờ' : '${d.inHours} giờ $m phút';
  }
  final h = d.inHours % 24;
  return h == 0 ? '${d.inDays} ngày' : '${d.inDays} ngày $h giờ';
}

/// Đếm ngược `4:05`.
String formatCountdown(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${s ~/ 60}:${_two(s % 60)}';
}
