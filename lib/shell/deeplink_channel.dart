import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'deeplink_resolver.dart';
import 'remote_config.dart';

/// 接收原生回传的 `umatch://<token>` 深链并驱动激活。
///
/// 调用链:
///   AppDelegate.application(_:open:) / launchOptions[.url]
///     → MethodChannel com.uu.umatch/deeplink (onLink / getInitialLink)
///     → DeepLinkService._handle(token)
///     → RemoteConfigService.fetch() (确保 atk/au 已缓存)
///     → DeepLinkResolver.resolve(token) (本地 tryActivate 命中或服务端兜底)
///     → onLanding(url) → 路由到 LandingWebView
class DeepLinkService {
  static final DeepLinkService shared = DeepLinkService._();
  DeepLinkService._();

  static const MethodChannel _channel = MethodChannel('com.uu.umatch/deeplink');

  void Function(String url)? _onLanding;
  bool _inited = false;

  /// [onLanding] 在解析出落地 URL 时回调（导航到 LandingWebView）。
  Future<void> init({required void Function(String url) onLanding}) async {
    _onLanding = onLanding;
    if (_inited) return;
    _inited = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        await _handle(call.arguments as String?);
      }
      return null;
    });

    // 冷启动经深链拉起：取一次初始链接
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null && initial.isNotEmpty) {
        await _handle(initial);
      }
    } catch (_) {}
  }

  Future<void> _handle(String? url) async {
    if (url == null || url.isEmpty) return;
    const prefix = 'umatch://';
    if (!url.toLowerCase().startsWith(prefix)) return;

    // 从原始字符串取 token（不走 Uri.host，避免被强制小写，atk 大小写敏感全等）
    var token = url.substring(prefix.length);
    final slash = token.indexOf('/');
    if (slash >= 0) token = token.substring(0, slash);
    final query = token.indexOf('?');
    if (query >= 0) token = token.substring(0, query);
    token = token.trim();
    if (token.isEmpty) return;
    debugPrint('UMSHELL deeplink _handle url=$url token=$token');

    // 确保最新 cfg 已缓存 (atk/au)，让本地 tryActivate 命中并持久化激活
    await RemoteConfigService.shared.fetch();
    final landing = await DeepLinkResolver.shared.resolve(token);
    debugPrint('UMSHELL deeplink resolve -> ${landing ?? "null"}');
    if (landing != null && landing.isNotEmpty) {
      _onLanding?.call(landing);
    } else {
      debugPrint('UMSHELL deeplink: token 未解析出落地 URL');
    }
  }
}
