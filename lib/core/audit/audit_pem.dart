import 'dart:convert';
import 'dart:typed_data';

/// PEM-Encoding / -Decoding für Ed25519 Schlüssel.
///
/// Ed25519 hat in PKCS#8/SPKI feste DER-Prefixe (RFC 8410). Wir nutzen
/// diese statisch — kein vollständiger ASN.1-Parser nötig.
class AuditPem {
  AuditPem._();

  // PKCS#8 Prefix für Ed25519 Private Key (16 Byte) — RFC 8410.
  static const List<int> _ed25519PrivPrefix = [
    0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06,
    0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
  ];

  // SPKI Prefix für Ed25519 Public Key (12 Byte) — RFC 8410.
  static const List<int> _ed25519PubPrefix = [
    0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65,
    0x70, 0x03, 0x21, 0x00,
  ];

  static const _privHeader = '-----BEGIN PRIVATE KEY-----';
  static const _privFooter = '-----END PRIVATE KEY-----';
  static const _pubHeader = '-----BEGIN PUBLIC KEY-----';
  static const _pubFooter = '-----END PUBLIC KEY-----';

  static String encodePrivate(Uint8List rawSeed) {
    if (rawSeed.length != 32) {
      throw ArgumentError(
          'Ed25519 Private Seed muss 32 Byte sein (war: ${rawSeed.length}).');
    }
    final der = Uint8List.fromList([..._ed25519PrivPrefix, ...rawSeed]);
    return _wrapPem(der, _privHeader, _privFooter);
  }

  static String encodePublic(Uint8List rawPub) {
    if (rawPub.length != 32) {
      throw ArgumentError(
          'Ed25519 Public Key muss 32 Byte sein (war: ${rawPub.length}).');
    }
    final der = Uint8List.fromList([..._ed25519PubPrefix, ...rawPub]);
    return _wrapPem(der, _pubHeader, _pubFooter);
  }

  /// Liest die rohen 32 Byte Seed aus einem PKCS#8-Ed25519-PEM.
  static Uint8List decodePrivate(String pem) {
    final der = _unwrapPem(pem, _privHeader, _privFooter);
    if (der.length != _ed25519PrivPrefix.length + 32 ||
        !_startsWith(der, _ed25519PrivPrefix)) {
      throw FormatException(
          'PEM-Datei ist kein Ed25519-Private-Key (PKCS#8, RFC 8410).');
    }
    return Uint8List.fromList(der.sublist(_ed25519PrivPrefix.length));
  }

  /// Liest die rohen 32 Byte aus einem SPKI-Ed25519-PEM.
  static Uint8List decodePublic(String pem) {
    final der = _unwrapPem(pem, _pubHeader, _pubFooter);
    if (der.length != _ed25519PubPrefix.length + 32 ||
        !_startsWith(der, _ed25519PubPrefix)) {
      throw FormatException(
          'PEM-Datei ist kein Ed25519-Public-Key (SPKI, RFC 8410).');
    }
    return Uint8List.fromList(der.sublist(_ed25519PubPrefix.length));
  }

  static String _wrapPem(List<int> der, String header, String footer) {
    final b64 = base64Encode(der);
    final lines = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }
    return '$header\n${lines.join('\n')}\n$footer\n';
  }

  static List<int> _unwrapPem(String pem, String header, String footer) {
    final headerIdx = pem.indexOf(header);
    final footerIdx = pem.indexOf(footer);
    if (headerIdx < 0 || footerIdx <= headerIdx) {
      throw FormatException(
          'PEM ungültig — Header oder Footer nicht gefunden.');
    }
    final body =
        pem.substring(headerIdx + header.length, footerIdx).replaceAll(RegExp(r'\s+'), '');
    return base64Decode(body);
  }

  static bool _startsWith(List<int> haystack, List<int> prefix) {
    if (haystack.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (haystack[i] != prefix[i]) return false;
    }
    return true;
  }
}
