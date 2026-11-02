import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/supabase/app_backend.dart';

/// اختبارات عميل Supabase — فق ADR-0009 §2 و§التبعات.
///
/// المنهجية: حقن `onConfigured` فلا يُلمس Supabase.initialize ولا
/// الشبكة إطلاقًا؛ الغياب (الوضع المحلي) هو الحالة التي يجريها
/// CI في الواقع لأن dart-define غير مضروب في الاختبارات.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseConfig', () {
    test('غياب متغيرات البيئة يعيد null — وضع محلي خالص', () {
      // لا dart-define مضروب في flutter test: منEnvironment فارغة.
      expect(SupabaseConfig.fromEnvironment(), isNull);
    });

    test('منح المعاملات مباشرة يعيد تكوينًا سليمًا', () {
      const config = SupabaseConfig(url: 'https://x.supabase.co', anonKey: 'k');
      expect(config.url, 'https://x.supabase.co');
      expect(config.anonKey, 'k');
    });
  });

  group('AppBackend.init', () {
    test('بلا تكوين: configured=false ولا استدعاء أي دالة اتصال', () async {
      final backend = await AppBackend.init();
      expect(backend.configured, isFalse);
      expect(AppBackend.instance.configured, isFalse);
    });

    test('بتكوين حقن: configured=true والدالة تسلم التكوين نفسه', () async {
      const config = SupabaseConfig(url: 'https://x.supabase.co', anonKey: 'k');
      final received = <SupabaseConfig>[];
      final backend = await AppBackend.init(
        config: config,
        onConfigured: (c) async => received.add(c),
      );
      expect(backend.configured, isTrue);
      expect(AppBackend.instance.configured, isTrue);
      expect(received, hasLength(1));
      expect(received.single.anonKey, 'k');
    });

    test('إعادة init بلا تكوين بعد تكوين: يرجع للوضع المحلي', () async {
      const config = SupabaseConfig(url: 'https://x.supabase.co', anonKey: 'k');
      await AppBackend.init(config: config, onConfigured: (_) async {});
      expect(AppBackend.instance.configured, isTrue);

      final backend = await AppBackend.init();
      expect(backend.configured, isFalse);
      expect(AppBackend.instance.configured, isFalse);
    });
  });
}
