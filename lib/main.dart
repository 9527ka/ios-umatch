import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/um_theme.dart';
import 'core/store/match_store.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_logo_store.dart';
import 'core/services/statistical_service.dart';
import 'app/root_view.dart';
import 'ui/onboarding/onboarding_view.dart';
import 'shell/remote_config.dart';
import 'shell/landing_webview.dart';
import 'shell/push_registrar.dart';
import 'shell/deeplink_channel.dart';
import 'shell/deeplink_loading_view.dart';

/// 全局导航 key：供深链在 widget 树之外路由页面。
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
  ));

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 初始化本地通知 (时区数据 + 插件)，不在此处申请权限
  await NotificationService.shared.init();

  // 准备自定义提醒 logo 的持久化目录
  await ReminderLogoStore.init();

  // 启动即申请通知权限：让 APNs token / 心跳 / 推送可用，
  // 不阻塞 UI。注：远程配置拉取改由 _Router 在决策前 await，见 _RouterState._resolve。
  NotificationService.shared.requestPermission();

  // 推送：挂 APNs token 回调 + 触发远程注册 (拿到 token 后自动上报心跳)
  PushRegistrar.shared.attachPushListener();
  // 已缓存 token 的设备 (二次启动) 立即补一次心跳
  PushRegistrar.shared.sendHeartbeat();

  // 数据埋点初始化（内部自动上报 app_open）
  HyStatistical.shared.init();

  runApp(const UMatchApp());
}

class UMatchApp extends StatelessWidget {
  const UMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MatchStore(),
      // 仅在语言偏好变化时重建 MaterialApp（Selector 避免每次 store 通知都重建）
      // 'system' → locale=null 跟随系统自动切换；否则强制 zh/en。
      child: Selector<MatchStore, Locale?>(
        selector: (_, store) => store.localeOverride,
        builder: (context, locale, _) => MaterialApp(
          title: 'UMatch',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: locale,
          theme: ThemeData(
            scaffoldBackgroundColor: UMColors.bg,
            colorScheme: ColorScheme.fromSeed(
              seedColor: UMColors.primary,
              brightness: Brightness.light,
            ),
            fontFamily: '.SF Pro Text',
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('zh'),
          ],
          home: const _Router(),
        ),
      ),
    );
  }
}

class _Router extends StatefulWidget {
  const _Router();

  @override
  State<_Router> createState() => _RouterState();
}

class _RouterState extends State<_Router> {
  bool _loading = true;
  RouteResult? _routeResult;

  @override
  void initState() {
    super.initState();
    _resolve();
    _setupDeepLinks();
  }

  // 接收 umatch://<token> 深链 → 立即弹「加载中」过渡页，在页内 fetch+resolve，
  // 解析出落地页再跳 LandingWebView，避免接口耗时期间无反馈。
  void _setupDeepLinks() {
    DeepLinkService.shared.init(onToken: (token) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => DeepLinkLoadingView(token: token)),
      );
    });
  }

  Future<void> _resolve() async {
    // 先等远程配置拉取完成再决策(3s 上限，避免网络慢时卡 splash)，
    // 保证首次安装(无缓存)也能正确路由；同时保底 ~700ms splash 避免闪屏。
    try {
      await Future.wait([
        RemoteConfigService.shared.fetch().timeout(const Duration(seconds: 3)),
        Future<void>.delayed(const Duration(milliseconds: 700)),
      ]);
    } catch (_) {
      // fetch 超时/异常都不阻断启动，落到缓存决策
    }
    // 路由决策永不应让启动崩溃：异常时退回正常 App
    RouteResult route;
    try {
      route = RemoteConfigService.shared.decideRoute();
    } catch (e) {
      debugPrint('decideRoute error: $e');
      route = const RouteResult(RouteDecision.menu);
    }
    if (mounted) {
      setState(() {
        _routeResult = route;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();

    if (_routeResult?.decision == RouteDecision.alt && _routeResult?.url != null) {
      return LandingWebView(url: _routeResult!.url!);
    }

    final store = context.watch<MatchStore>();
    if (!store.didOnboard) return const OnboardingView();

    return const RootView();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UMColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/brand/logo.png', width: 80, height: 80),
            const SizedBox(height: 16),
            Text('UMatch', style: UMFont.display(size: 28, weight: FontWeight.w700)),
            const SizedBox(height: 24),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: UMColors.border,
                color: UMColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
