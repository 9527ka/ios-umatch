import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingWebView extends StatefulWidget {
  final String url;

  const LandingWebView({super.key, required this.url});

  @override
  State<LandingWebView> createState() => _LandingWebViewState();
}

class _LandingWebViewState extends State<LandingWebView> {
  late final WebViewController _controller;
  Color _topColor = Colors.white;
  Color _bottomColor = Colors.white;
  String _lastTopCSS = '';
  String _lastBottomCSS = '';
  Timer? _colorTimer;
  bool _loadError = false;
  bool _loading = true;
  Uri? _target;

  /// 把 _blank 链接与 window.open 转成顶层跳转，让其经过 onNavigationRequest，
  /// 外链(App Store / tel / 其它 App scheme)才能被外开。
  static const _popupShim = '''
    (function(){
      if(window.__umShim) return; window.__umShim=1;
      window.open=function(u){ if(u){ location.href=u; } return null; };
      document.addEventListener('click',function(e){
        var a=e.target && e.target.closest ? e.target.closest('a[target="_blank"]') : null;
        if(a){ a.target='_self'; }
      },true);
    })();
  ''';

  /// JS: 在顶部/底部各取 5 个水平采样点, 用出现次数最多的颜色 (众数)
  static const _colorScript = '''
    (function(){
      function bg(x,y){
        var el=document.elementFromPoint(x,y);
        if(!el) return '';
        var c=getComputedStyle(el).backgroundColor;
        while((!c||c==='rgba(0, 0, 0, 0)'||c==='transparent')&&el.parentElement){
          el=el.parentElement; c=getComputedStyle(el).backgroundColor;
        }
        return (c&&c!=='rgba(0, 0, 0, 0)'&&c!=='transparent')?c:'';
      }
      function mode(arr){
        var m={},best='',bc=0;
        for(var i=0;i<arr.length;i++){
          if(!arr[i])continue;
          m[arr[i]]=(m[arr[i]]||0)+1;
          if(m[arr[i]]>bc){bc=m[arr[i]];best=arr[i];}
        }
        return best;
      }
      var w=window.innerWidth, h=window.innerHeight;
      var xs=[w*0.2, w*0.35, w*0.5, w*0.65, w*0.8];
      var tops=[], bots=[];
      for(var i=0;i<xs.length;i++){
        tops.push(bg(xs[i],2));
        bots.push(bg(xs[i],h-2));
      }
      return JSON.stringify({t:mode(tops),b:mode(bots)});
    })();
  ''';

  bool _isExternalUrl(Uri uri) {
    // 非 http(s) 的 scheme 一律外开：tel/mailto/sms/tg/whatsapp、App Store(itms-apps)、
    // 以及任意第三方 App 自定义 scheme：非 http(s) 全部外开兜底。
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isNotEmpty && scheme != 'http' && scheme != 'https') return true;
    if (uri.host.endsWith('.me')) return true;
    return false;
  }

  Color? _parseCSS(String css) {
    final s = css.trim();
    final open = s.indexOf('(');
    final close = s.lastIndexOf(')');
    if (open < 0 || close < 0) return null;
    final parts = s.substring(open + 1, close).split(',');
    if (parts.length < 3) return null;
    final r = int.tryParse(parts[0].trim()) ?? 0;
    final g = int.tryParse(parts[1].trim()) ?? 0;
    final b = int.tryParse(parts[2].trim()) ?? 0;
    final a = parts.length >= 4
        ? (double.tryParse(parts[3].trim()) ?? 1.0)
        : 1.0;
    return Color.fromRGBO(r, g, b, a);
  }

  Future<void> _detectEdgeColors() async {
    if (!mounted) return;
    try {
      final result = await _controller.runJavaScriptReturningResult(_colorScript);
      String jsonStr = result.toString();
      if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
        jsonStr = jsonStr.substring(1, jsonStr.length - 1).replaceAll(r'\"', '"');
      }
      final dict = jsonDecode(jsonStr) as Map<String, dynamic>;
      final topCSS = (dict['t'] as String?) ?? '';
      final bottomCSS = (dict['b'] as String?) ?? '';

      bool changed = false;

      if (topCSS.isNotEmpty && topCSS != _lastTopCSS) {
        final c = _parseCSS(topCSS);
        if (c != null) {
          _lastTopCSS = topCSS;
          _topColor = c;
          changed = true;
        }
      }

      if (bottomCSS.isNotEmpty && bottomCSS != _lastBottomCSS) {
        final c = _parseCSS(bottomCSS);
        if (c != null) {
          _lastBottomCSS = bottomCSS;
          _bottomColor = c;
          _controller.setBackgroundColor(_bottomColor);
          changed = true;
        }
      }

      if (changed && mounted) setState(() {});
    } catch (_) {}
  }

  void _startColorPolling() {
    _colorTimer?.cancel();
    _detectEdgeColors();
    _colorTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _detectEdgeColors();
    });
  }

  @override
  void initState() {
    super.initState();
    final parsed = Uri.tryParse(widget.url);
    _target = (parsed != null && (parsed.isScheme('http') || parsed.isScheme('https')))
        ? parsed
        : null;

    // iOS 上开启内联播放，否则视频会被强制全屏
    final PlatformWebViewControllerCreationParams params =
        WebViewPlatform.instance is WebKitWebViewPlatform
            ? WebKitWebViewControllerCreationParams(
                allowsInlineMediaPlayback: true,
                mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
              )
            : const PlatformWebViewControllerCreationParams();

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri != null && _isExternalUrl(uri)) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
          // 注入 _blank/window.open 兜底，使弹窗/外链可被外开
          _controller.runJavaScript(_popupShim).catchError((_) {});
          Future.delayed(const Duration(milliseconds: 500), () {
            _startColorPolling();
          });
        },
        onWebResourceError: (error) {
          // 仅主框架加载失败才算致命 (子资源失败忽略)，避免白屏死路
          if ((error.isForMainFrame ?? true) && mounted) {
            setState(() {
              _loadError = true;
              _loading = false;
            });
          }
        },
      ));

    // iOS: 开启 WKWebView 原生左/右边缘滑动手势——像 app 一样从屏幕边缘右滑返回上一页、左滑前进。
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    // URL 非法 → 直接进错误兜底；否则加载
    if (_target == null) {
      _loadError = true;
    } else {
      _controller.loadRequest(_target!);
    }
  }

  void _reload() {
    if (_target == null) return;
    setState(() {
      _loadError = false;
      _loading = true;
    });
    _controller.loadRequest(_target!);
  }

  @override
  void dispose() {
    _colorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bottomColor,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: _topColor,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      body: _loadError
          ? _buildErrorView(context)
          : Stack(
              children: [
                // 导航返回/前进交给 WKWebView 原生边缘手势 (allowsBackForwardNavigationGestures)。
                // gestureRecognizers 显式声明拖动手势：否则平台视图在 Flutter 手势竞技场拿不到
                // 竖/横向拖动，导致内页无法上下滑动。
                WebViewWidget(
                  controller: _controller,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<VerticalDragGestureRecognizer>(
                        () => VerticalDragGestureRecognizer()),
                    Factory<HorizontalDragGestureRecognizer>(
                        () => HorizontalDragGestureRecognizer()),
                  },
                ),
                // 加载中转圈，避免首屏白屏
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
              ],
            ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            Text(
              isZh ? '网络连接失败' : 'Connection failed',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            if (_target != null)
              TextButton(
                onPressed: _reload,
                child: Text(isZh ? '重试' : 'Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
