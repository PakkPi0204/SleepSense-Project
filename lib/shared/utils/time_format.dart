/// Formats a timestamp as relative time ("5 minutes ago"), shared by the Alerts
/// and Morning Report screens so the user can see how recent an event is.
String formatRelativeTime(DateTime? timestamp) {
  if (timestamp == null) return '';

  final now = DateTime.now().toUtc();
  final ts = timestamp.isUtc ? timestamp : timestamp.toUtc();
  final diff = now.difference(ts);

  if (diff.isNegative || diff.inSeconds < 60) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes} min ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours} hr ago';
  } else {
    return '${diff.inDays} days ago';
  }
}
