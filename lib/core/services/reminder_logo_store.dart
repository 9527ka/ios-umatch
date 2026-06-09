import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 持久化「自定义提醒」上传的 logo 图片。
///
/// image_picker 返回的是临时缓存路径，App 重启后可能被系统清理；
/// 这里把选中的图片复制到文档目录下的 `reminder_logos/`，并只在
/// [NotifyConfig.logo] 里存相对文件名 (`upload:<filename>`)，渲染时再
/// 用缓存的目录拼回绝对路径——避免存绝对路径(iOS 容器 UUID 会变)。
///
/// 调用链：
///   main.dart → ReminderLogoStore.init() (启动时缓存目录)
///   ReminderSheet 选图 → save() 拷贝并返回文件名
///   ReminderLogoView 渲染 → pathFor() 解析为可读绝对路径
class ReminderLogoStore {
  ReminderLogoStore._();

  static String? _dir;

  /// 启动时调用一次，缓存并确保目录存在。
  static Future<void> init() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/reminder_logos');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _dir = dir.path;
    } catch (_) {
      _dir = null;
    }
  }

  /// 相对文件名 → 绝对路径；目录未就绪或传 null 时返回 null。
  static String? pathFor(String? fileName) {
    if (fileName == null || _dir == null) return null;
    return '$_dir/$fileName';
  }

  /// 把 [srcPath] 的图片复制进文档目录，文件名按 matchId 唯一化 (覆盖旧的)。
  /// 返回持久化后的相对文件名；失败返回 null。
  static Future<String?> save(String srcPath, String matchId) async {
    if (_dir == null) await init();
    if (_dir == null) return null;
    try {
      final ext = _extOf(srcPath);
      // matchId 可能含非法文件名字符，做一次清洗
      final safeId = matchId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final fileName = 'rl_$safeId$ext';
      final dest = '$_dir/$fileName';
      await File(srcPath).copy(dest);
      return fileName;
    } catch (_) {
      return null;
    }
  }

  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot < path.length - 6) return '.jpg';
    return path.substring(dot).toLowerCase();
  }
}
