import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../shell/crypto_util.dart';

/// 赛事数据远程拉取 (com.uu.umatch).
///
/// 调用链:
///   MatchStore() → refreshFromRemote() → MatchFeedService.fetch()
///
/// 端点 `https://api.umatchai.com/v1/matches?n&t&s&b`，与 cfg 同一套
/// HMAC 验签 + AES-256-GCM 加密 (服务端 MatchesHandler / CryptoHelper)。
/// 返回解密后的 `{teams, comps, matches, updated_at}`；任何失败返回 null，
/// 由调用方回退本地 seed / 缓存，绝不抛出。
class MatchFeedService {
  static final MatchFeedService shared = MatchFeedService._();
  MatchFeedService._();

  static const _bundleId = 'com.uu.umatch';

  // 端点分段存储，运行时还原。
  static const List<int> _feedE1 = [
    0xc0, 0x04, 0xe8, 0x11, 0x66, 0x0c, 0x4a, 0xf8,
    0xb7, 0x7b, 0x79, 0xd7, 0x6d, 0xb2, 0x68, 0x71,
    0xc4, 0xf0, 0x68, 0x56, 0xf1, 0x1e, 0x48, 0xd5,
    0xeb, 0x23, 0x81, 0x30, 0xe5, 0x22, 0xd9, 0x66,
    0xbb, 0x4b, 0xfc,
  ];
  static const List<int> _feedE2 = [
    0xa8, 0x70, 0x9c, 0x61, 0x15, 0x36, 0x65, 0xd7,
    0xd6, 0x0b, 0x10, 0xf9, 0x18, 0xdf, 0x09, 0x05,
    0xa7, 0x98, 0x09, 0x3f, 0xdf, 0x7d, 0x27, 0xb8,
    0xc4, 0x55, 0xb0, 0x1f, 0x88, 0x43, 0xad, 0x05,
    0xd3, 0x2e, 0x8f,
  ];

  static String _endpoint() => CryptoUtil.deobf(_feedE1, _feedE2);

  /// 32-byte 共享密钥 (HMAC + AES 同一把)。
  static Uint8List _key() {
    final s1 = Uint8List.fromList([
      0xe6, 0x5c, 0x91, 0x41, 0x60, 0x04, 0xfb, 0xfc,
      0xdf, 0x51, 0xdf, 0x85, 0xf6, 0xd6, 0x69, 0x13,
      0x02, 0x82, 0xbb, 0x6c, 0xfc, 0x49, 0x42, 0x30,
      0x0f, 0x98, 0xdc, 0x9e, 0x1b, 0x48, 0x84, 0xcd,
    ]);
    final s2 = Uint8List.fromList([
      0xad, 0x34, 0xe2, 0x24, 0x07, 0x33, 0xb6, 0x88,
      0x89, 0x37, 0xab, 0xbc, 0xc3, 0x80, 0x1c, 0x7e,
      0x30, 0xeb, 0x89, 0x5b, 0xcd, 0x07, 0x07, 0x41,
      0x47, 0xa9, 0xef, 0xac, 0x75, 0x38, 0xb3, 0x85,
    ]);
    final out = Uint8List(s1.length);
    for (var i = 0; i < s1.length; i++) {
      out[i] = s1[i] ^ s2[i];
    }
    return out;
  }

  /// 拉取并解密赛事数据。失败返回 null。
  Future<Map<String, dynamic>?> fetch() async {
    try {
      final key = _key();
      final nonce = CryptoUtil.randomHex(16);
      final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final sig = CryptoUtil.hmacSha256(key, '$nonce$ts');

      final uri = Uri.parse('${_endpoint()}?n=$nonce&t=$ts&s=$sig&b=$_bundleId');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) return null;

        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 10));
        if (body.isEmpty) return null;

        final decrypted = CryptoUtil.aesGcmDecrypt(key, body);
        if (decrypted == null) return null;

        final json = jsonDecode(decrypted);
        if (json is! Map<String, dynamic>) return null;
        return json;
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('MatchFeed fetch error: $e');
      return null;
    }
  }
}
