import 'dart:math';

/// RFC 4122 v4 UUID Generator
/// Generates standard UUIDs compatible with PostgreSQL UUID columns and Supabase primary keys
class UuidUtil {
  static final Random _random = Random.secure();

  static String newUuid() {
    final values = List<int>.generate(16, (i) => _random.nextInt(256));
    // Set version to 4: bits 12-15 of time_hi_and_version to 0100
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122: bits 6-7 of clock_seq_hi_and_reserved to 01
    values[8] = (values[8] & 0x3f) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
