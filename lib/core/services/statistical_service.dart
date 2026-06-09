import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shell/crypto_util.dart';

/// HyStatistical 数据埋点 SDK（Dart 版）。
///
/// 调用链:
///   main.dart → HyStatistical.shared.init()                      // 自动 app_open
///   RootView.didChangeAppLifecycleState resumed → foreground()   // 自动 app_foreground
///   各业务页 → HyStatistical.shared.track('event_name', {...})    // 核心业务事件
///
/// 上报: POST `${serverUrl}/collect`，body `{"events":[...]}`，头 `X-Api-Key`。
/// serverUrl 与 apiKey 分段存储，运行时还原。
class HyStatistical {
  static final HyStatistical shared = HyStatistical._();
  HyStatistical._();

  // serverUrl `https://s.97rich.vip/api/v1` 分段存储，运行时还原。
  static const List<int> _stU1 = [
    0xce, 0xc4, 0x21, 0xb5, 0x6b, 0xfb, 0xef, 0x40,
    0xb7, 0x42, 0x27, 0xfd, 0xb5, 0xac, 0xe7, 0x44,
    0xfa, 0x5d, 0xdd, 0xe5, 0xe9, 0x3d, 0x09, 0x85,
    0x3c, 0x13, 0x7a,
  ];
  static const List<int> _stU2 = [
    0xa6, 0xb0, 0x55, 0xc5, 0x18, 0xc1, 0xc0, 0x6f,
    0xc4, 0x6c, 0x1e, 0xca, 0xc7, 0xc5, 0x84, 0x2c,
    0xd4, 0x2b, 0xb4, 0x95, 0xc6, 0x5c, 0x79, 0xec,
    0x13, 0x65, 0x4b,
  ];

  // apiKey `hy_38dbd039b3804b499c163bca4348c935` (app_id com.uu.umatch,
  // 后台 s.97rich.vip 注册), 分段存储，运行时还原。
  static const List<int> _stK1 = [
    0x10, 0x86, 0x3d, 0x37, 0x22, 0x37, 0xd8, 0x00,
    0x53, 0x49, 0x4a, 0x7b, 0xf8, 0x80, 0xb9, 0x20,
    0x07, 0xb5, 0xc2, 0xfb, 0x81, 0x49, 0x7b, 0xa3,
    0x57, 0xdb, 0x9b, 0x6b, 0xb3, 0x3c, 0x16, 0x55,
    0x0b, 0x80, 0xf6,
  ];
  static const List<int> _stK2 = [
    0x78, 0xff, 0x62, 0x04, 0x1a, 0x53, 0xba, 0x64,
    0x63, 0x7a, 0x73, 0x19, 0xcb, 0xb8, 0x89, 0x14,
    0x65, 0x81, 0xfb, 0xc2, 0xe2, 0x78, 0x4d, 0x90,
    0x35, 0xb8, 0xfa, 0x5f, 0x80, 0x08, 0x2e, 0x36,
    0x32, 0xb3, 0xc3,
  ];

  // App 版本：与 pubspec version 同步（无 package_info 依赖，手动维护）。
  static const String _appVersion = '1.0.0';
  static const int _flushSize = 50;
  static const Duration _flushInterval = Duration(seconds: 10);
  static const int _maxRetries = 3;
  static const String _deviceIdKey = 'hy.device_id';
  static const String _offlineKey = 'hy.offline_events';

  bool _inited = false;
  String _serverUrl = '';
  String _apiKey = '';
  String _deviceId = '';
  String _sessionId = '';
  String? _userId;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;
  bool _flushing = false;
  SharedPreferences? _prefs;

  // device_id 持久化到 iOS Keychain（kSecAttrAccessibleAfterFirstUnlock），
  // 卸载重装存活。SharedPreferences 卸载即清，会导致每次重装生成新
  // device_id、虚高独立设备数。
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    _serverUrl = CryptoUtil.deobf(_stU1, _stU2);
    _apiKey = CryptoUtil.deobf(_stK1, _stK2);
    _prefs = await SharedPreferences.getInstance();
    _deviceId = await _resolveDeviceId();
    _sessionId = _newSession();
    _restoreOffline();
    _timer?.cancel();
    _timer = Timer.periodic(_flushInterval, (_) => flush());
    track('app_open');
  }

  void setUserId(String? userId) => _userId = userId;

  /// 回到前台：开新 session 并上报 app_foreground。
  void foreground() {
    if (!_inited) return;
    _sessionId = _newSession();
    track('app_foreground');
  }

  void track(String name, [Map<String, dynamic>? props]) {
    if (!_inited) return;
    final ev = <String, dynamic>{
      'platform': 'ios',
      'event_name': name,
      'event_time': DateTime.now().toUtc().toIso8601String(),
      'device_id': _deviceId,
      'session_id': 's_$_sessionId',
      'insert_id': _uuid(),
      'app_version': _appVersion,
      'os_version': _osVersion(),
    };
    if (_userId != null && _userId!.isNotEmpty) ev['user_id'] = _userId;
    if (props != null && props.isNotEmpty) ev['properties'] = props;
    _queue.add(ev);
    if (_queue.length >= _flushSize) flush();
  }

  Future<void> flush() async {
    if (!_inited || _flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      final batchCount = _queue.length < _flushSize ? _queue.length : _flushSize;
      final batch = _queue.sublist(0, batchCount);
      final outcome = await _send(batch);
      switch (outcome) {
        case _SendResult.success:
        case _SendResult.clientError:
          // 成功 / 4xx：都移除这批（重试无用）。期间队列只增不减，removeRange 安全。
          final n = batchCount < _queue.length ? batchCount : _queue.length;
          _queue.removeRange(0, n);
          if (_queue.isEmpty) _clearOffline();
          break;
        case _SendResult.retryable:
          _saveOffline();
          break;
      }
    } finally {
      _flushing = false;
    }
  }

  Future<_SendResult> _send(List<Map<String, dynamic>> batch) async {
    final uri = Uri.parse('$_serverUrl/collect');
    final body = jsonEncode({'events': batch});
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
        try {
          final req = await client.postUrl(uri);
          req.headers.set('Content-Type', 'application/json');
          req.headers.set('X-Api-Key', _apiKey);
          req.write(body);
          final resp = await req.close().timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) return _SendResult.success;
          if (resp.statusCode >= 400 && resp.statusCode < 500) {
            return _SendResult.clientError;
          }
        } finally {
          client.close(force: true);
        }
      } catch (_) {
        // 网络错误：落入重试
      }
      if (attempt < _maxRetries - 1) {
        await Future.delayed(Duration(seconds: 1 << attempt)); // 1s, 2s
      }
    }
    return _SendResult.retryable;
  }

  /// device_id 解析顺序（async-safe，全程 await）：
  ///   1. Keychain（卸载重装存活）—— 命中直接用；
  ///   2. 旧 SharedPreferences 'hy.device_id' —— 一次性迁移进 Keychain；
  ///   3. 都没有 —— 生成新 UUID 写入 Keychain。
  /// 始终回写 SharedPreferences 作镜像缓存（兼容、可读性）。
  Future<String> _resolveDeviceId() async {
    String? id;
    try {
      id = await _secure.read(key: _deviceIdKey);
    } catch (_) {
      id = null;
    }
    if (id != null && id.isNotEmpty) {
      _prefs!.setString(_deviceIdKey, id);
      return id;
    }
    // 迁移：旧版本只存在 SharedPreferences。
    final legacy = _prefs!.getString(_deviceIdKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _writeSecure(legacy);
      return legacy;
    }
    final fresh = _uuid();
    await _writeSecure(fresh);
    _prefs!.setString(_deviceIdKey, fresh);
    return fresh;
  }

  Future<void> _writeSecure(String id) async {
    try {
      await _secure.write(key: _deviceIdKey, value: id);
    } catch (_) {
      // Keychain 写入失败（极端情况）：降级仍走 SharedPreferences 镜像。
    }
  }

  void _saveOffline() {
    if (_queue.isEmpty) return;
    _prefs?.setString(_offlineKey, jsonEncode(_queue));
  }

  void _restoreOffline() {
    final s = _prefs?.getString(_offlineKey);
    if (s == null) return;
    try {
      final list = (jsonDecode(s) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      _queue.insertAll(0, list);
    } catch (_) {}
    _prefs?.remove(_offlineKey);
  }

  void _clearOffline() => _prefs?.remove(_offlineKey);

  String _osVersion() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'unknown';
    }
  }

  String _newSession() => _uuid().substring(0, 8);

  /// RFC4122 v4 UUID（无 uuid 依赖，Random.secure 生成）。
  String _uuid() {
    final r = Random.secure();
    final b = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      b[i] = r.nextInt(256);
    }
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
        '-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

enum _SendResult { success, clientError, retryable }
