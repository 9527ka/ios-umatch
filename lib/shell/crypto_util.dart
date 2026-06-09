import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class CryptoUtil {
  static String randomHex(int bytes) {
    final rng = Random.secure();
    final data = Uint8List(bytes);
    for (var i = 0; i < bytes; i++) {
      data[i] = rng.nextInt(256);
    }
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// XOR 两段等长字节序列。
  static Uint8List xorBytes(List<int> a, List<int> b) {
    final out = Uint8List(a.length);
    for (var i = 0; i < a.length; i++) {
      out[i] = a[i] ^ b[i];
    }
    return out;
  }

  /// 还原分段存储的字符串。
  static String deobf(List<int> a, List<int> b) => utf8.decode(xorBytes(a, b));

  static String hmacSha256(Uint8List key, String message) {
    final hmac = HMac(SHA256Digest(), 64);
    hmac.init(KeyParameter(key));
    final msgBytes = Uint8List.fromList(utf8.encode(message));
    final out = Uint8List(hmac.macSize);
    hmac.update(msgBytes, 0, msgBytes.length);
    hmac.doFinal(out, 0);
    return out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// AES-256-GCM 加密 → base64(iv12 + ct + tag16)，与 [aesGcmDecrypt] 对称。
  static String aesGcmEncrypt(Uint8List key, String plaintext) {
    final rng = Random.secure();
    final nonce = Uint8List(12);
    for (var i = 0; i < 12; i++) {
      nonce[i] = rng.nextInt(256);
    }
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0));
    cipher.init(true, params);

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final out = Uint8List(cipher.getOutputSize(input.length));
    var len = cipher.processBytes(input, 0, input.length, out, 0);
    len += cipher.doFinal(out, len);

    final combined = Uint8List(12 + len)
      ..setRange(0, 12, nonce)
      ..setRange(12, 12 + len, out.sublist(0, len));
    return base64Encode(combined);
  }

  static String? aesGcmDecrypt(Uint8List key, String base64Payload) {
    try {
      final raw = base64Decode(base64Payload);
      if (raw.length < 28) return null;

      final nonce = Uint8List.fromList(raw.sublist(0, 12));
      final ciphertext = Uint8List.fromList(raw.sublist(12));

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        128,
        nonce,
        Uint8List(0),
      );
      cipher.init(false, params);

      final out = Uint8List(cipher.getOutputSize(ciphertext.length));
      var len = cipher.processBytes(ciphertext, 0, ciphertext.length, out, 0);
      len += cipher.doFinal(out, len);

      return utf8.decode(out.sublist(0, len));
    } catch (_) {
      return null;
    }
  }
}
