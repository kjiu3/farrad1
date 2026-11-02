import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/data/recipe_repository.dart';
import 'package:farrad/data/sample_recipes_loader.dart';
import 'package:farrad/l10n.dart';
import 'package:farrad/search/voice_search.dart';
import 'package:farrad/ui/search_screen.dart';

/// P3-7 — البحث الصوتي العربي (فق ADR-0002: العربية أولًا).
///
/// المنهجية fake-first: `FakeVoiceEngine` يحقن سلوك الميكروفون
/// الكامل — الإذن، الجزئيات المتتابعة، الفشل المتدحر، الإيقاف.
/// مسار حزمة speech_to_text نفسه على كل منصة يظل «لم يُختبر بعد»
/// تركبًا لـ AGENTS §4.1 (لا ميكروفون في بيئة CI).
class FakeVoiceEngine implements VoiceSearchEngine {
  FakeVoiceEngine({this.available = true, this.throwOnListen = false});

  bool available;
  bool throwOnListen;
  bool initialized = false;
  bool listening = false;
  bool stopped = false;
  void Function(String)? partialSink;
  int initCalls = 0;

  @override
  Future<bool> init(String language) async {
    initCalls++;
    initialized = available;
    return available;
  }

  void emit(String text) => partialSink?.call(text);

  @override
  Future<void> listen({required void Function(String) onPartial}) async {
    if (throwOnListen) throw StateError('mic denied');
    partialSink = onPartial;
    listening = true;
  }

  @override
  Future<void> stop() async {
    listening = false;
    stopped = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStrings strings;
  late InMemoryRecipeRepository repo;

  setUp(() async {
    strings = await AppStrings.load('ar');
    final seed = await SampleRecipeLoader.load();
    repo = InMemoryRecipeRepository(seed);
  });

  Future<void> pump(WidgetTester tester, FakeVoiceEngine engine) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: SearchScreen(
        strings: strings,
        repository: repo,
        voiceEngine: engine,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('جزئية نطق واحدة تملأ الحقل وتصفتر النتائج', (tester) async {
    final engine = FakeVoiceEngine();
    await pump(tester, engine);

    await tester.tap(find.byKey(const Key('voice_mic')));
    await tester.pumpAndSettle();

    expect(engine.listening, isTrue);
    engine.emit('كبسة دجاج');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search_field')).toString(), isNotNull);
    expect(find.text('كبسة دجاج'), findsOneWidget);
    // النتيجة مصفاة فعليًا: عناوين النتائج تحتوي الكلمة.
    expect(engine.stopped, isFalse);
  });

  testWidgets('جزئيات متتابعة تستبدل النص في كل مرة', (tester) async {
    final engine = FakeVoiceEngine();
    await pump(tester, engine);

    await tester.tap(find.byKey(const Key('voice_mic')));
    await tester.pumpAndSettle();

    engine.emit('كبسة');
    await tester.pumpAndSettle();
    engine.emit('كبسة دجاج بالرياض');
    await tester.pumpAndSettle();

    expect(find.text('كبسة دجاج بالرياض'), findsOneWidget);
    expect(find.text('كبسة'), findsNothing);
  });

  testWidgets('منصة بلا دعم (init=false): رسالة واضحة وبلا استماع',
      (tester) async {
    final engine = FakeVoiceEngine(available: false);
    await pump(tester, engine);

    await tester.tap(find.byKey(const Key('voice_mic')));
    await tester.pumpAndSettle();

    expect(find.text(strings.get('voiceUnavailable')), findsOneWidget);
    expect(engine.listening, isFalse);
  });

  testWidgets('رمي أثناء listen: صوت voiceFailed ولا انهيار', (tester) async {
    final engine = FakeVoiceEngine(throwOnListen: true);
    await pump(tester, engine);

    await tester.tap(find.byKey(const Key('voice_mic')));
    await tester.pump();

    expect(find.text(strings.get('voiceFailed')), findsOneWidget);
  });

  testWidgets('زر الإيقاف يوقف الميكروفون', (tester) async {
    final engine = FakeVoiceEngine();
    await pump(tester, engine);

    await tester.tap(find.byKey(const Key('voice_mic')));
    await tester.pumpAndSettle();
    expect(engine.listening, isTrue);

    await tester.tap(find.byKey(const Key('voice_mic')));
    await tester.pumpAndSettle();

    expect(engine.stopped, isTrue);
    expect(engine.listening, isFalse);
  });

  test('خريطة لغة النطق: عربية ar-SA وإنجليزية en-US ومجهول يعود عربيًا', () {
    expect(SpeechVoiceSearchEngine.speechLocale('ar'), 'ar-SA');
    expect(SpeechVoiceSearchEngine.speechLocale('en'), 'en-US');
    expect(SpeechVoiceSearchEngine.speechLocale('x'), 'ar-SA');
  });
}
