import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/um_theme.dart';
import '../core/store/match_store.dart';
import '../core/services/widget_sync_service.dart';
import '../core/services/statistical_service.dart';
import '../shell/push_registrar.dart';
import '../l10n/um_strings.dart';
import '../ui/home/home_view.dart';
import '../ui/matches/matches_view.dart';
import '../ui/widgets_screen/widgets_view.dart';
import '../ui/wallpapers/wallpapers_view.dart';
import '../ui/settings/settings_view.dart';

/// Bubble this from any child to switch the bottom tab.
class SwitchTabNotification extends Notification {
  final int index;
  const SwitchTabNotification(this.index);
}

class RootView extends StatefulWidget {
  const RootView({super.key});

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Locale? _lastLocale;

  final _screens = const [
    HomeView(),
    WidgetsView(),
    MatchesView(),
    WallpapersView(),
    SettingsView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWidget());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 语言切换后用新语言重刷小组件 / 灵动岛文案
    final loc = Localizations.localeOf(context);
    if (_lastLocale != null && _lastLocale != loc) _syncWidget();
    _lastLocale = loc;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台时刷新小组件，使其推进到下一场比赛
      _syncWidget();
      HyStatistical.shared.foreground();
      // 前台心跳：刷新后端"活跃"状态
      PushRegistrar.shared.sendHeartbeat();
    } else if (state == AppLifecycleState.paused) {
      // 退后台前冲刷埋点队列
      HyStatistical.shared.flush();
      // 退出前最后一次心跳上报
      PushRegistrar.shared.sendHeartbeat();
    }
  }

  void _syncWidget() {
    if (!mounted) return;
    WidgetSyncService.sync(context.read<MatchStore>(), Localizations.localeOf(context));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);

    return NotificationListener<SwitchTabNotification>(
      onNotification: (n) {
        _switchTab(n.index);
        return true;
      },
      child: Scaffold(
      backgroundColor: UMColors.bg,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: UMColors.surface,
          border: Border(top: BorderSide(color: UMColors.border, width: 0.5)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: s.tabHome, active: _currentIndex == 0, onTap: () => _switchTab(0)),
                _TabItem(icon: Icons.widgets_outlined, activeIcon: Icons.widgets, label: s.tabWidgets, active: _currentIndex == 1, onTap: () => _switchTab(1)),
                _TabItem(icon: Icons.sports_soccer_outlined, activeIcon: Icons.sports_soccer, logoAsset: 'assets/brand/logo.png', label: s.tabMatches, active: _currentIndex == 2, onTap: () => _switchTab(2)),
                _TabItem(icon: Icons.wallpaper_outlined, activeIcon: Icons.wallpaper, label: s.tabWallpapers, active: _currentIndex == 3, onTap: () => _switchTab(3)),
                _TabItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: s.tabSettings, active: _currentIndex == 4, onTap: () => _switchTab(4)),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  void _switchTab(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      setState(() => _currentIndex = index);
    }
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String? logoAsset;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    this.logoAsset,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 真实品牌 logo（彩色图，无法双色着色），用透明度区分选中态
            logoAsset != null
                ? Opacity(
                    opacity: active ? 1.0 : 0.4,
                    child: Image.asset(logoAsset!, width: 22, height: 22, fit: BoxFit.contain),
                  )
                : Icon(
                    active ? activeIcon : icon,
                    size: 22,
                    color: active ? UMColors.primary : UMColors.textTertiary,
                  ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? UMColors.primary : UMColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
