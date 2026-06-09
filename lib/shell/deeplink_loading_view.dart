import 'package:flutter/material.dart';
import '../core/theme/um_theme.dart';
import 'remote_config.dart';
import 'deeplink_resolver.dart';
import 'landing_webview.dart';

/// 深链激活「加载中」过渡页。
///
/// 收到 `umatch://<token>` 后立即展示(品牌 logo + 转圈)，避免解析接口耗时期间
/// 停在原界面没有任何反馈；解析完成后：
/// - 拿到落地 URL → pushReplacement 到 [LandingWebView]
/// - 没拿到(激活失败/网络失败) → pop 回原界面
class DeepLinkLoadingView extends StatefulWidget {
  final String token;

  const DeepLinkLoadingView({super.key, required this.token});

  @override
  State<DeepLinkLoadingView> createState() => _DeepLinkLoadingViewState();
}

class _DeepLinkLoadingViewState extends State<DeepLinkLoadingView> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    // 确保最新 cfg 已缓存 (atk/au)，让本地 tryActivate 命中并持久化激活
    await RemoteConfigService.shared.fetch();
    final url = await DeepLinkResolver.shared.resolve(widget.token);
    debugPrint('UMSHELL deeplink resolve -> ${url ?? "null"}');
    if (!mounted) return;
    if (url != null && url.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LandingWebView(url: url)),
      );
    } else {
      // 解析失败：退回到原界面（正常 App / 上一个页面）
      debugPrint('UMSHELL deeplink: token 未解析出落地 URL');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return Scaffold(
      backgroundColor: UMColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/brand/logo.png', width: 72, height: 72),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: UMColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              isZh ? '加载中…' : 'Loading…',
              style: UMFont.body(size: 14).copyWith(color: UMColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
