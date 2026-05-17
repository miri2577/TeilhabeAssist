import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Liefert eine kryptografisch sichere `SecureRandom`-Instanz für
/// pointycastle, geseedet aus `dart:math` `Random.secure()` (nutzt
/// OS-Entropie: `/dev/urandom`, `BCryptGenRandom`, `getrandom`).
///
/// Ersetzt den fehlerhaften, zeitbasierten Seed der Vorversion.
SecureRandom newSecureRandom() {
  final rng = math.Random.secure();
  final seed = Uint8List(32);
  for (var i = 0; i < seed.length; i++) {
    seed[i] = rng.nextInt(256);
  }
  final random = FortunaRandom();
  random.seed(KeyParameter(seed));
  return random;
}

/// Erzeugt N zufällige Bytes aus dem OS-Entropie-Pool.
Uint8List secureRandomBytes(int length) {
  final rng = math.Random.secure();
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = rng.nextInt(256);
  }
  return out;
}

/// Constant-time-Vergleich für Byte-Arrays.
/// Verhindert Timing-Seitenkanäle bei Hash-/MAC-Vergleichen.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
