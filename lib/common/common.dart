import 'dart:math';
import 'dart:ui';

Color topAndBottomNavigationBarColor= Color(0xFF1f1a54);

String generateSecureToken() {
  const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  final rnd = Random.secure();
  return String.fromCharCodes(Iterable.generate(20, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}