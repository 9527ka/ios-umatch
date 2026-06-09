import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'crypto_util.dart';
import 'remote_config.dart';

class DeepLinkResolver {
  static final DeepLinkResolver shared = DeepLinkResolver._();
  DeepLinkResolver._();

  static Uint8List _key() {
    final k1 = Uint8List.fromList([
      0xb2, 0x3e, 0x91, 0x5a, 0xc7, 0x48, 0x0d, 0xf6,
      0x73, 0xa9, 0x14, 0x8b, 0xd5, 0x62, 0x3f, 0xc0,
      0xe1, 0x57, 0x8a, 0x26, 0xbd, 0x49, 0x03, 0x7e,
      0x95, 0xd8, 0x41, 0xfc, 0x0b, 0x6a, 0x2c, 0xe3,
    ]);
    final k2 = Uint8List.fromList([
      0xe0, 0x6c, 0xc3, 0x08, 0x95, 0x1a, 0x5f, 0xa4,
      0x21, 0xfb, 0x46, 0xd9, 0x87, 0x30, 0x6d, 0x92,
      0xb3, 0x05, 0xd8, 0x74, 0xef, 0x1b, 0x51, 0x2c,
      0xc7, 0x8a, 0x13, 0xae, 0x59, 0x38, 0x7e, 0xb1,
    ]);
    final out = Uint8List(k1.length);
    for (var i = 0; i < k1.length; i++) {
      out[i] = k1[i] ^ k2[i];
    }
    return out;
  }

  // 端点分段存储，运行时还原为 https://api.umatchai.com/dl/r
  // （统一到 api.umatchai.com，与 cfg/feed/heartbeat 同域）。
  static const List<int> _dlE1 = [
    0x7b, 0x3d, 0x9d, 0xd4, 0x5d, 0xa6, 0x0f, 0x84,
    0x74, 0x08, 0x28, 0x1e, 0x71, 0xa4, 0xcd, 0xa2,
    0x84, 0xb2, 0xa2, 0x8f, 0x53, 0xbf, 0xda, 0xd3,
    0x39, 0x34, 0x68, 0x20, 0x3f,
  ];
  static const List<int> _dlE2 = [
    0x13, 0x49, 0xe9, 0xa4, 0x2e, 0x9c, 0x20, 0xab,
    0x15, 0x78, 0x41, 0x30, 0x04, 0xc9, 0xac, 0xd6,
    0xe7, 0xda, 0xc3, 0xe6, 0x7d, 0xdc, 0xb5, 0xbe,
    0x16, 0x50, 0x04, 0x0f, 0x4d,
  ];

  static String _endpoint() => CryptoUtil.deobf(_dlE1, _dlE2);

  Future<String?> resolve(String token) async {
    try {
      final activated = await RemoteConfigService.shared.tryActivate(token);
      if (activated) {
        final route = RemoteConfigService.shared.decideRoute();
        if (route.decision == RouteDecision.alt) return route.url;
      }

      final nonce = CryptoUtil.randomHex(16);
      final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      const bundleId = 'com.uu.umatch';

      // 用 queryParameters 让 token 等值正确转义，避免 &/#/空格 破坏请求
      final uri = Uri.parse(_endpoint()).replace(queryParameters: {
        't': token,
        'n': nonce,
        'ts': ts,
        'b': bundleId,
      });
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

        final decrypted = CryptoUtil.aesGcmDecrypt(_key(), body);
        if (decrypted == null) return null;

        final json = jsonDecode(decrypted) as Map<String, dynamic>;
        return json['url'] as String?;
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('DeepLink resolve error: $e');
      return null;
    }
  }
}
