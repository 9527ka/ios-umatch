import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 接收原生回传的 `umatch://<token>` 深链，解析出 token 后交给上层。
///
/// 调用链:
///   AppDelegate.application(_:open:) / launchOptions[.url]
///     → MethodChannel com.uu.umatch/deeplink (onLink / getInitialLink)
///     → DeepLinkService._handle(url) 解析 token
///     → onToken(token) → 上层弹出「加载中」过渡页 (DeepLinkLoadingView)，
///       在过渡页里 fetch + resolve，再跳 LandingWebView。
class DeepLinkService {
  static final DeepLinkService shared = DeepLinkService._();
  DeepLinkService._();

  static const MethodChannel _channel = MethodChannel('com.uu.umatch/deeplink');

  void Function(String token)? _onToken;
  bool _inited = false;

  /// [onToken] 在解析出合法 token 时立即回调（用于弹出加载中过渡页）。
  Future<void> init({required void Function(String token) onToken}) async {
    _onToken = onToken;
    if (_inited) return;
    _inited = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        _handle(call.arguments as String?);
      }
      return null;
    });

    // 冷启动经深链拉起：取一次初始链接
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null && initial.isNotEmpty) {
        _handle(initial);
      }
    } catch (_) {}
  }

  void _handle(String? url) {
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

    _onToken?.call(token);
  }
}
