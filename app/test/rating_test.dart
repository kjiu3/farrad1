import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/auth/auth_service.dart';
import 'package:farrad/community/comment_service.dart';
import 'package:farrad/community/rating_service.dart';
import 'package:farrad/data/recipe_repository.dart';
import 'package:farrad/data/sample_recipes_loader.dart';
import 'package:farrad/l10n.dart';
import 'package:farrad/models/recipe.dart';
import 'package:farrad/supabase/app_backend.dart';
import 'package:farrad/ui/recipe_detail_screen.dart';

/// P3-6 — التقييم (نجوم 1..5، رقعة واحدة لكل مستخدم، متوسط محسوب)
/// فق ADR-0009 §4 وP3-2 schema (recipe_ratings بمفتاح مشترك).
///
/// المنهجية fake-first (AGENTS §2.1): بلا شبكة إطلاقًا؛ مسار
/// PostgREST الحي (upsert بالمفتاح المشترك) يظل «لم يُختبر بعد»
/// تركبًا لـ AGENTS §4.1 حتى مفاتيح المالك.
class FakeRatingService implements RatingService {
  FakeRatingService({List<int>? scores, int? myRating, this.failRate})
      : scores = scores ?? const <int>[],
        _my = myRating;

  List<int> scores;
  int? _my;
  bool? failRate;

  int? lastRequestedScore;
  bool rateCalled = false;

  @override
  Future<List<int>> listScores(String recipeId) async => scores;

  @override
  Future<int?> getMyRating(String recipeId) async => _my;

  @override
  Future<CommunityOutcome> rate(String recipeId, int score) async {
    rateCalled = true;
    lastRequestedScore = score;
    if (failRate ?? false) {
      return const CommunityOutcome(ok: false, errorKey: 'ratingFailed');
    }
    _my = score;
    scores = [...scores, score];
    return const CommunityOutcome(ok: true);
  }
}

class FakeAuthService implements AuthService {
  FakeAuthService({this.initial});

  String? initial;

  @override
  String? get userId => initial;

  @override
  Future<AuthOutcome> signIn(String email, String password) async =>
      const AuthOutcome(ok: false, errorKey: 'authFailed');

  @override
  Future<AuthOutcome> signUp(String email, String password) async =>
      const AuthOutcome(ok: false, errorKey: 'authFailed');

  @override
  Future<void> signOut() async {
    initial = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStrings strings;
  late InMemoryRecipeRepository repo;
  late Recipe first;

  setUp(() async {
    strings = await AppStrings.load('ar');
    final seed = await SampleRecipeLoader.load();
    repo = InMemoryRecipeRepository(seed);
    first = seed.first;
  });

  group('قاعدة حساب المتوسط (AGENTS §2.3: قاعدة بلا اختبار لا تُحسب مكتملة)', () {
    test('قائمة فاضية → عدّاد صفر ومتوسط فارغ، لا رقم كاذب', () {
      final s = RatingSummary.fromScores(const []);
      expect(s.count, 0);
      expect(s.average, isNull);
    });

    test('درجتان 5 و4 → متوسط 4.5 وعدّاد 2', () {
      final s = RatingSummary.fromScores(const [5, 4]);
      expect(s.count, 2);
      expect(s.average, 4.5);
    });

    test('دقة تفسير المتوسط: 1,2,4 → 2.3 لا 2.333…', () {
      final s = RatingSummary.fromScores(const [1, 2, 4]);
      expect(s.count, 3);
      expect(s.average, 2.3);
    });

    test('بيانات مخالفة (0 أو 6) تُقطع: لا متوسط ولا عدّاد', () {
      expect(RatingSummary.fromScores(const [5, 0, 3]).average, isNull);
      expect(RatingSummary.fromScores(const [6]).average, isNull);
      expect(RatingSummary.fromScores(const [6]).count, 0);
    });
  });

  group('الخدمة الافتراضية بلا مفاتيح — فشل آمن بلا شبكة (ADR-0009 §2)', () {
    test('listScores وgetMyRating: وضع محلي → فاضية/null', () async {
      const service = SupabaseRatingService();
      expect(AppBackend.instance.configured, isFalse);
      expect(await service.listScores(first.id), isEmpty);
      expect(await service.getMyRating(first.id), isNull);
    });

    test('rate: وضع محلي → ratingRequireAuth ولا كتابة', () async {
      const service = SupabaseRatingService();
      final outcome = await service.rate(first.id, 5);
      expect(outcome.ok, isFalse);
      expect(outcome.errorKey, 'ratingRequireAuth');
    });

    test('rate بدرجة خارج 1..5 → رفض فوري قبل أي اتصال', () async {
      const service = SupabaseRatingService();
      final zero = await service.rate(first.id, 0);
      final six = await service.rate(first.id, 6);
      expect(zero.ok, isFalse);
      expect(six.ok, isFalse);
      expect(zero.errorKey, 'ratingFailed');
      expect(six.errorKey, 'ratingFailed');
    });
  });

  group('نجمات التقييم في شاشة العرض', () {
    Future<void> pumpDetail(
      WidgetTester tester, {
      required FakeRatingService ratings,
      required FakeAuthService auth,
    }) async {
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: RecipeDetailScreen(
          strings: strings,
          repository: repo,
          recipeId: first.id,
          ratingService: ratings,
          authService: auth,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('بلا تقييمات: نص «بلا تقييم بعد» والنجمات فارغة',
        (tester) async {
      await pumpDetail(
        tester,
        ratings: FakeRatingService(),
        auth: FakeAuthService(initial: 'u-test'),
      );
      expect(find.byKey(const Key('rating_summary')), findsOneWidget);
      expect(find.text(strings.get('ratingNone')), findsOneWidget);
    });

    testWidgets('ملخص موجود: 4.5 ★ (2) يعرض ومعه تقييمي جمّل نجمتين',
        (tester) async {
      await pumpDetail(
        tester,
        ratings: FakeRatingService(scores: [5, 4], myRating: 4),
        auth: FakeAuthService(initial: 'u-test'),
      );
      // الملخص نصيًا بالمتوسط والعدّاد.
      expect(find.text('4.5 ★ (2)'), findsOneWidget);
      // نجماتي: الأولى..الرابعة ممتلئة، الخامسة فارغة.
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsNWidgets(1));
    });

    testWidgets('مجهول: لمسة نجمة → «سجّل الدخول للتقييم» بلا استدعاء',
        (tester) async {
      final ratings = FakeRatingService();
      await pumpDetail(
        tester,
        ratings: ratings,
        auth: FakeAuthService(), // بلا مستخدم
      );

      await tester.tap(find.byKey(const Key('rating_star_5')));
      await tester.pumpAndSettle();

      expect(find.text(strings.get('ratingRequireAuth')), findsOneWidget);
      expect(ratings.rateCalled, isFalse);
    });

    testWidgets('مسجّل ونجمة 5: rate بـ 5 وتتلألأ الخمسة نجمات ممتلئة',
        (tester) async {
      final ratings = FakeRatingService();
      await pumpDetail(
        tester,
        ratings: ratings,
        auth: FakeAuthService(initial: 'u-test'),
      );

      await tester.tap(find.byKey(const Key('rating_star_5')));
      await tester.pumpAndSettle();

      expect(ratings.rateCalled, isTrue);
      expect(ratings.lastRequestedScore, 5);
      // الخمس نجمات ممتلئة بعد النجاح.
      expect(find.byIcon(Icons.star), findsNWidgets(5));
      expect(find.byIcon(Icons.star_border), findsNWidgets(0));
    });

    testWidgets('فشل الخدمة: رسالة الفشل وألا انهيار', (tester) async {
      final ratings = FakeRatingService(failRate: true);
      await pumpDetail(
        tester,
        ratings: ratings,
        auth: FakeAuthService(initial: 'u-test'),
      );

      await tester.tap(find.byKey(const Key('rating_star_2')));
      await tester.pumpAndSettle();

      expect(find.text(strings.get('ratingFailed')), findsOneWidget);
      expect(ratings.lastRequestedScore, 2);
    });
  });
}
