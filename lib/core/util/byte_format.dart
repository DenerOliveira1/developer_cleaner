/// Formats a byte count as `B/KB/MB/GB/TB` (binary, base-1024).
///
/// Shared by the CLI engine and the UI so sizes read identically everywhere.
String formatBytes(int? bytes, {int decimals = 1}) {
  if (bytes == null) return '?';
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var size = bytes.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  // Bytes have no fractional part; everything above shows [decimals].
  final str = i == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(decimals);
  return '$str ${units[i]}';
}
