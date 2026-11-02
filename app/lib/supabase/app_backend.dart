import 'package:supabase_flutter/supabase_flutter.dart';

/// إعداد الاتصال الحي بالخلفية — فق ADR-0009 §2.
///
/// المفاتيح تمر عبر `--dart-define` (أو `.env` غير متتبع) ولا تُكتب
/// في المستودع أبدًا (AGENTS §3.1). غيابهما يعني وضعًا محليًا خالصًا
/// كما في المرحلة 2 — لا انهيارًا ولا اتصالًا.
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  final String url;
  final String anonKey;

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// null = لا تكوين (وضع محلي خالص). عنوان غير HTTPS أو مفتاح
  /// فارغ يُعامَل كغياب (فشل آمن، لا اتصال).
  static SupabaseConfig? fromEnvironment() {
    if (_envUrl.isEmpty || _envKey.isEmpty) return null;
    if (!_envUrl.startsWith('https://')) return null;
    return SupabaseConfig(url: _envUrl, anonKey: _envKey);
  }
}

/// وجهة كل PR لاحق في المرحلة 3: عميل حي أو null.
///
/// `onConfigured` حقن للاختبار — الإنتاج يمرر دالة Supabase.initialize
/// بنفسه، والاختبار يمرر دالة تسجّل الاستدعاء فلا يُلمس الشبكة إطلاقًا.
class AppBackend {
  const AppBackend._({required this.configured});

  final bool configured;

  static AppBackend _instance = const AppBackend._(configured: false);
  static AppBackend get instance => _instance;

  /// عميل Supabase الحي أو null في الوضع المحلي.
  static SupabaseClient? get clientOrNull =>
      _instance.configured ? Supabase.instance.client : null;

  /// يُستدعى مرة عند الإقلاع. بلا تكوين: بلا اتصال جدًا.
  static Future<AppBackend> init({
    SupabaseConfig? config,
    Future<void> Function(SupabaseConfig config)? onConfigured,
  }) async {
    config ??= SupabaseConfig.fromEnvironment();
    if (config == null) {
      _instance = const AppBackend._(configured: false);
      return _instance;
    }
    if (onConfigured != null) {
      await onConfigured(config);
    } else {
      // publishableKey هو الاسم الجديد؛ مفتاح anon القديم مقبول فيه
      // بنيويًا (supabase_flutter 2.18).
      await Supabase.initialize(url: config.url, publishableKey: config.anonKey);
    }
    _instance = const AppBackend._(configured: true);
    return _instance;
  }
}
