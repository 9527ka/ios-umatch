import 'dart:ui';

class LocalizedString {
  final String en;
  final String zh;

  const LocalizedString({required this.en, required this.zh});

  String resolve([Locale? locale]) {
    final l = locale ?? PlatformDispatcher.instance.locale;
    return l.languageCode == 'zh' ? zh : en;
  }

  factory LocalizedString.fromJson(Map<String, dynamic> json) {
    return LocalizedString(en: json['en'] as String, zh: json['zh'] as String);
  }

  Map<String, dynamic> toJson() => {'en': en, 'zh': zh};

  @override
  String toString() => resolve();
}
