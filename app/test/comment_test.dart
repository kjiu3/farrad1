import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/auth/auth_service.dart';
import 'package:farrad/community/comment_service.dart';
import 'package:farrad/data/recipe_repository.dart';
import 'package:farrad/data/sample_recipes_loader.dart';
import 'package:farrad/l10n.dart';
import 'package:farrad/models/recipe.dart';
import 'package:farrad/supabase/app_backend.dart';
import 'package:farrad/ui/recipe_detail_screen.dart';

/// P3-5 — التعليقات (فق ADR-0009 §4: الكتابة لمالكها، القراءة للجميع).
///
/// المنهجية fake-first (AGENTS §2.1): حقن `FakeCommentService` و
/// `FakeAuthService` — لا شبكة إطلاقًا. مسار PostgREST الحي يظل
/// «لم يُختبر بعد» تركبًا لـ AGENTS §4.1 حتى مفاتيح المالك.
class FakeCommentService implements CommentService {
  FakeCommentService({List<RecipeComment>? comments, this.fail})
      : comments = comments ?? const <RecipeComment>[];

  List<RecipeComment> comments;
  bool? fail;
  final List<String> bodies = <String>[];
  final List<String> recipeIds = <String>[];
  bool addCalled = false;

  @override
  Future<List<RecipeComment>> list(String recipeId) async {
    return comments;
  }

  @override
  Future<CommunityOutcome> add(String recipeId, String body) async {
    addCalled = true;
    recipeIds.add(recipeId);
    bodies.add(body);
    if (fail ?? false) {
      return const CommunityOutcome(ok: false, errorKey: 'commentFailed');
    }
    final c = RecipeComment(
      id: 'c${bodies.length}',
      recipeId: recipeId,
      userId: 'u-test',
      body: body,
    );
    comments = [...comments, c];
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

  group('الخدمة الافتراضية بلا مفاتيح — فشل آمن بلا شبكة (ADR-0009 §2)', () {
    test('list: وضع محلي → قائمة فاضية', () async {
      final service = const SupabaseCommentService();
      final comments = await service.list(first.id);
      expect(comments, isEmpty);
    });

    test('add: وضع محلي → commentRequireAuth ولا كتابة', () async {
      final service = const SupabaseCommentService();
      expect(AppBackend.instance.configured, isFalse);
      final outcome = await service.add(first.id, 'نص');
      expect(outcome.ok, isFalse);
      expect(outcome.errorKey, 'commentRequireAuth');
    });
  });

  group('قسم التعليقات في شاشة العرض', () {
    Future<void> pumpDetail(
      WidgetTester tester, {
      required FakeCommentService comments,
      required FakeAuthService auth,
    }) async {
      // منفذ طويل حتى يبني ListView كله أبناءه: زر الإرسال أسفل
      // القسم الأخير، والبناء المنتقي يتخطى ما خارج الشاشة فلا
      // يتوفر للسحب (لا scrollUntilVisible على أبناء غير مبنية).
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: RecipeDetailScreen(
          strings: strings,
          repository: repo,
          recipeId: first.id,
          commentService: comments,
          authService: auth,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('عرض القائمة: تعليقان مرئيان ومعنوان القسم', (tester) async {
      final comments = FakeCommentService(comments: [
        const RecipeComment(
          id: 'c1', recipeId: 'r', userId: 'u1', body: 'تعليق أول',
        ),
        const RecipeComment(
          id: 'c2', recipeId: 'r', userId: 'u2', body: 'تعليق ثانٍ',
        ),
      ]);
      await pumpDetail(tester, comments: comments, auth: FakeAuthService());

      expect(find.text(_k(strings, 'commentsTitle')), findsOneWidget);
      expect(find.text('تعليق أول'), findsOneWidget);
      expect(find.text('تعليق ثانٍ'), findsOneWidget);
      expect(
        find.byKey(const Key('comments_empty')),
        findsNothing,
      );
    });

    testWidgets('لا تعليقات بعد: حالة فاضية مرئية', (tester) async {
      await pumpDetail(
        tester,
        comments: FakeCommentService(),
        auth: FakeAuthService(),
      );
      expect(find.text(_k(strings, 'commentEmpty')), findsOneWidget);
      expect(
        find.byKey(const Key('comments_empty')),
        findsOneWidget,
      );
    });

    testWidgets('مجهول: منع النشر ورسالة «سجّل الدخول» دون استدعاء الخدمة',
        (tester) async {
      final comments = FakeCommentService();
      await pumpDetail(
        tester,
        comments: comments,
        auth: FakeAuthService(), // userId == null
      );

      await tester.enterText(
        find.byKey(const Key('comment_input')),
        'بلا حساب',
      );
      await tester.tap(find.byKey(const Key('comment_send')));
      await tester.pumpAndSettle();

      expect(find.text(_k(strings, 'commentRequireAuth')), findsOneWidget);
      expect(comments.addCalled, isFalse);
      expect(comments.bodies, isEmpty);
    });

    testWidgets('فراغ: رفض فوري بلا استدعاء الخدمة', (tester) async {
      final comments = FakeCommentService();
      await pumpDetail(
        tester,
        comments: comments,
        auth: FakeAuthService(initial: 'u-test'),
      );

      await tester.enterText(find.byKey(const Key('comment_input')), '   ');
      await tester.tap(find.byKey(const Key('comment_send')));
      await tester.pumpAndSettle();

      expect(find.text(_k(strings, 'commentEmptyInput')), findsOneWidget);
      expect(comments.addCalled, isFalse);
    });

    testWidgets('مسجّل وتعليق سليم: يُسجَّل ويُضاف للقائمة وينظف الحقل',
        (tester) async {
      final comments = FakeCommentService();
      await pumpDetail(
        tester,
        comments: comments,
        auth: FakeAuthService(initial: 'u-test'),
      );

      await tester.enterText(
        find.byKey(const Key('comment_input')),
        'سلطة رائعة!',
      );
      await tester.tap(find.byKey(const Key('comment_send')));
      await tester.pumpAndSettle();

      expect(comments.addCalled, isTrue);
      expect(comments.recipeIds.single, first.id);
      expect(find.text('سلطة رائعة!'), findsOneWidget);
      expect(find.text(_k(strings, 'commentEmpty')), findsNothing);
    });

    testWidgets('فشل الخدمة: رسالة الفشل ويبقى النص في الحقل', (tester) async {
      final comments = FakeCommentService(fail: true);
      await pumpDetail(
        tester,
        comments: comments,
        auth: FakeAuthService(initial: 'u-test'),
      );

      await tester.enterText(
        find.byKey(const Key('comment_input')),
        'سيفشل هذا',
      );
      await tester.tap(find.byKey(const Key('comment_send')));
      await tester.pumpAndSettle();

      expect(find.text(_k(strings, 'commentFailed')), findsOneWidget);
      expect(comments.addCalled, isTrue);
      expect(comments.bodies, contains('سيفشل هذا'));
    });

    testWidgets('مدخل أطول من 1000 حرف: الحقل يقصه إلى حد المخطط',
        (tester) async {
      final comments = FakeCommentService();
      await pumpDetail(
        tester,
        comments: comments,
        auth: FakeAuthService(initial: 'u-test'),
      );

      await tester.enterText(
        find.byKey(const Key('comment_input')),
        'م' * 1001,
      );
      await tester.tap(find.byKey(const Key('comment_send')));
      await tester.pumpAndSettle();

      expect(comments.addCalled, isTrue);
      expect(comments.bodies.single.length, 1000, reason: 'حد المخطط 1000');
    });
  });
}

/// قراءة مفتاح ترجمة بخطأ بناء مبكر — يُفشل الاختبار على مفتاح غائب.
String _k(AppStrings strings, String key) => strings.get(key);
