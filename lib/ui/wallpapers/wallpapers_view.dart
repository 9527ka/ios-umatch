import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import '../../core/store/match_store.dart';
import '../../core/theme/um_theme.dart';
import '../../l10n/um_strings.dart';

// 分类索引: 0=全部 1=球场 2=足球 3=球队 4=霓虹 5=极简 6=复古 7=暗调
const int _catStadiums = 1;
const int _catFootballs = 2;
const int _catTeams = 3;
const int _catNeon = 4;
const int _catMinimal = 5;
const int _catRetro = 6;
const int _catDark = 7;

/// 单张壁纸: 要么是 asset 照片 (assetIndex)，要么是程序生成的渐变 (gradient)
class _Wallpaper {
  final String id;
  final int category;
  final int? assetIndex;
  final List<Color>? gradient;
  final Alignment begin;
  final Alignment end;
  final bool glow;
  final String? badge;

  const _Wallpaper.photo(this.id, this.category, this.assetIndex)
      : gradient = null,
        begin = Alignment.topLeft,
        end = Alignment.bottomRight,
        glow = false,
        badge = null;

  const _Wallpaper.grad(
    this.id,
    this.category,
    this.gradient, {
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.glow = true,
    this.badge,
  }) : assetIndex = null;

  bool get isPhoto => assetIndex != null;
}

Color _hex(String h) {
  h = h.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

List<_Wallpaper> _buildCatalog(MatchStore store) {
  final list = <_Wallpaper>[];

  // 球场 (体育场/球场照片)
  for (final i in const [1, 2, 3, 5, 7, 8, 9]) {
    list.add(_Wallpaper.photo('photo_$i', _catStadiums, i));
  }
  // 足球 (球/球鞋照片)
  for (final i in const [0, 4, 6]) {
    list.add(_Wallpaper.photo('photo_$i', _catFootballs, i));
  }

  // 球队 (由球队配色生成的渐变)
  for (final t in store.allTeams()) {
    list.add(_Wallpaper.grad(
      'team_${t.id}',
      _catTeams,
      [t.primaryColor, t.accentColor],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      badge: t.short3,
    ));
  }

  // 霓虹
  const neon = [
    ['#0F0C29', '#FF2D95'],
    ['#00C9FF', '#92FE9D'],
    ['#FC00FF', '#00DBDE'],
    ['#F72585', '#7209B7'],
    ['#08AEEA', '#2AF598'],
  ];
  for (var i = 0; i < neon.length; i++) {
    list.add(_Wallpaper.grad('neon_$i', _catNeon, [_hex(neon[i][0]), _hex(neon[i][1])]));
  }

  // 极简 (柔和浅色, 无光晕)
  const minimal = [
    ['#E0EAFC', '#CFDEF3'],
    ['#F5F7FA', '#C3CFE2'],
    ['#FDFBFB', '#EBEDEE'],
    ['#D7E1EC', '#FFFFFF'],
    ['#ECE9E6', '#FFFFFF'],
  ];
  for (var i = 0; i < minimal.length; i++) {
    list.add(_Wallpaper.grad('min_$i', _catMinimal, [_hex(minimal[i][0]), _hex(minimal[i][1])], glow: false));
  }

  // 复古 (暖色落日)
  const retro = [
    ['#FF6E7F', '#BFE9FF'],
    ['#FFB75E', '#ED8F03'],
    ['#F7971E', '#FFD200'],
    ['#C04848', '#480048'],
    ['#EB5757', '#1A1A2E'],
  ];
  for (var i = 0; i < retro.length; i++) {
    list.add(_Wallpaper.grad('retro_$i', _catRetro, [_hex(retro[i][0]), _hex(retro[i][1])]));
  }

  // 暗调
  const dark = [
    ['#000000', '#434343'],
    ['#141E30', '#243B55'],
    ['#0F2027', '#2C5364'],
    ['#232526', '#414345'],
    ['#16222A', '#3A6073'],
  ];
  for (var i = 0; i < dark.length; i++) {
    list.add(_Wallpaper.grad('dark_$i', _catDark, [_hex(dark[i][0]), _hex(dark[i][1])]));
  }

  return list;
}

class WallpapersView extends StatefulWidget {
  const WallpapersView({super.key});

  @override
  State<WallpapersView> createState() => _WallpapersViewState();
}

class _WallpapersViewState extends State<WallpapersView> {
  int _selectedCat = 0;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final store = context.read<MatchStore>();

    final catalog = _buildCatalog(store);
    final items = _selectedCat == 0
        ? catalog
        : catalog.where((w) => w.category == _selectedCat).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.wallpapers, style: UMFont.display(size: 32, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(s.wallpapersSub, style: UMFont.body(size: 14).copyWith(color: UMColors.textSecondary)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: s.wallCats.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final selected = _selectedCat == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCat = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(UMRadius.pill),
                        color: selected ? UMColors.textPrimary : UMColors.surface,
                        border: Border.all(color: selected ? UMColors.textPrimary : UMColors.border),
                      ),
                      child: Center(
                        child: Text(
                          s.wallCats[i],
                          style: UMFont.body(size: 13, weight: FontWeight.w500).copyWith(
                            color: selected ? Colors.white : UMColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 9 / 19.5,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _WallpaperTile(wp: items[index]),
                childCount: items.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

/// 渐变壁纸的可视化 (含可选光晕 + 球队角标)，预览与缩略图共用以保证保存的图与所见一致
class _GradientArt extends StatelessWidget {
  final _Wallpaper wp;
  final bool large;

  const _GradientArt({required this.wp, this.large = false});

  @override
  Widget build(BuildContext context) {
    final colors = wp.gradient!;
    final dark = colors.first.computeLuminance() < 0.5;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: wp.begin, end: wp.end, colors: colors),
          ),
        ),
        if (wp.glow)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 0.9,
                colors: [
                  Colors.white.withValues(alpha: dark ? 0.16 : 0.28),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        if (wp.badge != null)
          Center(
            child: Text(
              wp.badge!,
              style: TextStyle(
                fontSize: large ? 96 : 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
      ],
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  final _Wallpaper wp;

  const _WallpaperTile({required this.wp});

  static const _fallbackColors = [
    Color(0xFF1E3A8A), Color(0xFF047857), Color(0xFF7C3AED),
    Color(0xFFDC2626), Color(0xFF0369A1), Color(0xFF0F172A),
    Color(0xFFD97706), Color(0xFF059669), Color(0xFF4338CA),
    Color(0xFF9F1239),
  ];

  Color get _fallback => _fallbackColors[(wp.assetIndex ?? 0) % _fallbackColors.length];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPreview(context),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: wp.isPhoto
            ? Image.asset(
                'assets/wallpapers/wall_${wp.assetIndex}.jpg',
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => Container(
                  color: _fallback,
                  child: Center(
                    child: Opacity(
                    opacity: 0.5,
                    child: Image.asset('assets/brand/logo.png', width: 48, height: 48, fit: BoxFit.contain),
                  ),
                  ),
                ),
              )
            : _GradientArt(wp: wp),
      ),
    );
  }

  void _showPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (routeCtx) => _WallpaperPreview(wp: wp, fallbackColor: _fallback),
      ),
    );
  }
}

class _WallpaperPreview extends StatefulWidget {
  final _Wallpaper wp;
  final Color fallbackColor;

  const _WallpaperPreview({required this.wp, required this.fallbackColor});

  @override
  State<_WallpaperPreview> createState() => _WallpaperPreviewState();
}

class _WallpaperPreviewState extends State<_WallpaperPreview> {
  bool _saving = false;
  final GlobalKey _bgKey = GlobalKey();

  Future<void> _saveToPhotos() async {
    if (_saving) return;
    setState(() => _saving = true);

    final locale = Localizations.localeOf(context);
    final isZh = locale.languageCode == 'zh';

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();

      if (widget.wp.isPhoto) {
        final byteData = await rootBundle.load('assets/wallpapers/wall_${widget.wp.assetIndex}.jpg');
        await Gal.putImageBytes(byteData.buffer.asUint8List(), name: 'UMatch_${widget.wp.id}');
      } else {
        final bytes = await _captureGradient();
        await Gal.putImageBytes(bytes, name: 'UMatch_${widget.wp.id}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isZh ? '已保存到相册 ✓' : 'Saved to Photos ✓'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: UMColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isZh ? '保存失败，请检查相册权限' : 'Save failed. Please check photo permissions.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 把渐变背景层渲染为原生分辨率 PNG (排除时钟/按钮等覆盖层)
  Future<Uint8List> _captureGradient() async {
    final boundary = _bgKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('gradient boundary not ready');
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: dpr);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('encode failed');
    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final padding = MediaQuery.of(context).padding;

    final Widget background = widget.wp.isPhoto
        ? Image.asset(
            'assets/wallpapers/wall_${widget.wp.assetIndex}.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (ctx, err, st) => Container(color: widget.fallbackColor),
          )
        : RepaintBoundary(
            key: _bgKey,
            child: _GradientArt(wp: widget.wp, large: true),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            background,
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              top: padding.top + 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    s.wallMonth,
                    style: UMFont.body(size: 14).copyWith(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '9:41',
                    style: TextStyle(
                      fontSize: 88,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: padding.top + 8,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
            Positioned(
              bottom: padding.bottom + 24,
              left: 40,
              right: 40,
              child: GestureDetector(
                onTap: _saveToPhotos,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(UMRadius.button),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: _saving
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                      : Text(
                          s.wallSave,
                          textAlign: TextAlign.center,
                          style: UMFont.body(size: 16, weight: FontWeight.w600).copyWith(color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
