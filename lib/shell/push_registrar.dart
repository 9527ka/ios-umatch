import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'crypto_util.dart';

class PushRegistrar {
  static final PushRegistrar shared = PushRegistrar._();
  PushRegistrar._();

  static const _keyToken = 'umatch.notif.deviceToken';
  static const _keyAsked = 'umatch.notif.didAskPermission';

  // 心跳端点分段存储（与 cfg/dl/feed 同策略），运行时还原。
  static const List<int> _hbE1 = [
    0xbf, 0xed, 0x41, 0x0c, 0xa0, 0xb3, 0x34, 0xaf,
    0x4a, 0xff, 0x15, 0xa6, 0x71, 0xed, 0xae, 0xb5,
    0x50, 0x26, 0xc5, 0x97, 0x38, 0xe7, 0x99, 0x70,
    0x0b, 0xaa, 0x79, 0x58, 0xaf, 0x41, 0x10, 0x82,
    0x60, 0x46, 0x7a, 0xa7, 0xc4, 0x57, 0x56, 0x9d,
    0x4c, 0x10, 0x8e, 0x0b, 0x8e,
  ];
  static const List<int> _hbE2 = [
    0xd7, 0x99, 0x35, 0x7c, 0xd3, 0x89, 0x1b, 0x80,
    0x2b, 0x8f, 0x7c, 0x88, 0x04, 0x80, 0xcf, 0xc1,
    0x33, 0x4e, 0xa4, 0xfe, 0x16, 0x84, 0xf6, 0x1d,
    0x24, 0xdc, 0x48, 0x77, 0xcb, 0x24, 0x66, 0xeb,
    0x03, 0x23, 0x09, 0x88, 0xac, 0x32, 0x37, 0xef,
    0x38, 0x72, 0xeb, 0x6a, 0xfa,
  ];

  // 心跳 32 字节密钥（HMAC + AES 同一把），XOR 拆分。
  static const List<int> _hk1 = [
    0x2f, 0x94, 0xf5, 0xe9, 0x50, 0x8e, 0xb9, 0x05,
    0x59, 0x8a, 0xb7, 0x69, 0x42, 0x56, 0x19, 0x70,
    0x28, 0xe4, 0x49, 0x9b, 0x8c, 0x41, 0xa1, 0x9a,
    0x0b, 0x4b, 0x61, 0x21, 0xbb, 0x8b, 0xc8, 0xfe,
  ];
  static const List<int> _hk2 = [
    0x64, 0xfc, 0x86, 0x8c, 0x37, 0xb9, 0xf4, 0x71,
    0x0f, 0xec, 0xc3, 0x50, 0x77, 0x00, 0x6c, 0x1d,
    0x1a, 0x8d, 0x7b, 0xac, 0xbd, 0x0f, 0xe4, 0xeb,
    0x43, 0x7a, 0x52, 0x13, 0xd5, 0xfb, 0xff, 0xb6,
  ];

  static const MethodChannel _pushChannel = MethodChannel('com.uu.umatch/push');
  static const MethodChannel _envChannel = MethodChannel('com.uu.umatch/env');

  String _endpoint() => CryptoUtil.deobf(_hbE1, _hbE2);
  Uint8List _key() => CryptoUtil.xorBytes(_hk1, _hk2);

  /// 接入原生 APNs 注册：挂 token 回调 → 触发远程注册。
  /// 原生拿到 device token 后回调 onToken → 存储并立即上报心跳。
  /// 调用链: main.dart 启动时调用一次。
  void attachPushListener() {
    _pushChannel.setMethodCallHandler((call) async {
      if (call.method == 'onToken') {
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) {
          await storeToken(token);
          await sendHeartbeat();
        }
      }
      return null;
    });
    // 先挂 handler 再请求注册，避免 token 回调早于 handler 就绪而丢失。
    _pushChannel.invokeMethod('registerForRemote');
  }

  Future<void> sendHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyToken);
      if (token == null || token.isEmpty) return;

      final locale = PlatformDispatcher.instance.locale;
      // 业务字段 + 客户端遥测字段。
      final payload = jsonEncode({
        'device_token': token,
        'bundle_id': 'com.uu.umatch',
        'environment': await _apnsEnvironment(),
        'language': locale.languageCode == 'zh' ? 'zh' : 'en',
        'tz_offset': DateTime.now().timeZoneOffset.inMinutes,
        'fav_count': prefs.getStringList('umatch.followedTeams')?.length ?? 0,
        'season_id': 'wcf-2026',
      });

      // HMAC 签名查询 + AES-256-GCM 加密 body（与 cfg 同一套验签/加密模型）。
      final key = _key();
      final nonce = CryptoUtil.randomHex(16);
      final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final sig = CryptoUtil.hmacSha256(key, '$nonce$ts');
      final encBody = CryptoUtil.aesGcmEncrypt(key, payload);

      final uri = Uri.parse(
          '${_endpoint()}?n=$nonce&t=$ts&s=$sig&b=com.uu.umatch');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.postUrl(uri);
        request.headers.set('Content-Type', 'application/octet-stream');
        request.write(encBody);
        await request.close().timeout(const Duration(seconds: 10));
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('Heartbeat error: $e');
    }
  }

  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  Future<void> markAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAsked, true);
  }

  Future<bool> didAsk() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAsked) ?? false;
  }

  /// APNs 环境：决定后端用哪个网关推送。必须与 token 真实环境一致，否则 APNs
  /// 拒收 (BadDeviceToken)，收不到推送。
  ///
  /// 权威来源是原生侧解析签名描述文件的 `aps-environment`（见 AppDelegate
  /// .apnsEnvironment）——**不再靠 kDebugMode**：Release 调试包用的是 development
  /// 描述文件、拿到 sandbox token，按编译模式判断会误报 production。
  ///
  /// 非 iOS / 原生调用失败时兜底回退到 kDebugMode 推断。
  Future<String> _apnsEnvironment() async {
    if (!Platform.isIOS) return kDebugMode ? 'sandbox' : 'production';
    try {
      final env = await _envChannel.invokeMethod<String>('apnsEnvironment');
      if (env == 'sandbox' || env == 'production') return env!;
    } catch (_) {
      // 旧版二进制无此原生方法 / 解析异常：落回兜底
    }
    return kDebugMode ? 'sandbox' : 'production';
  }
}
