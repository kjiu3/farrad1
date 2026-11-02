import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/auth/auth_service.dart';
import 'package:farrad/data/recipe_repository.dart';
import 'package:farrad/data/sample_recipes_loader.dart';
import 'package:farrad/l10n.dart';
import 'package:farrad/ui/auth_screen.dart';
import 'package:farrad/ui/search_screen.dart';

/// P3-4 — شاشة الدخول/الجلسة (قرار المالك: كلمة مرور، ADR-0009 §1).
///
/// المنهجية: `FakeAuthService` حقن كامل — الواجهة والفروع والتحقق
/// تُختبر بلا شبكة؛ مسار gotrue الحي يظل «لم يُختبر بعد» مفعلاً
/// لـ AGENTS §4.1 حتى مفاتيح المالك.
class FakeAuthService implements AuthService {
  FakeAuthService({String? initialUserId}) {
    _userId = initialUserId;
  }

  String? _userId;

  @override
  String? get userId => _userId;

  bool failSignIn = false;
  bool failSignUp = false;
  final List<String> calls = <String>[];

  @override
  Future<AuthOutcome> signIn(String email, String password) async {
    calls.add('signIn');
    if (failSignIn) return const AuthOutcome(ok: false, errorKey: 'authFailed');
    _userId = 'u-test';
    return const AuthOutcome(ok: true, userId: 'u-test');
  }

  @override
  Future<AuthOutcome> signUp(String email, String password) async {
    calls.add('signUp');
    if (failSignUp) return const AuthOutcome(ok: false, errorKey: 'authFailed');
    _userId = 'u-test';
    return const AuthOutcome(ok: true, userId: 'u-test');
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _userId = null;
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

  Future<void> pumpSearch(
    WidgetTester tester,
    FakeAuthService auth, {
    bool useAuthScreen = false,
  }) async {
    if (useAuthScreen) {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: AuthScreen(strings: strings, service: auth),
      ));
      await tester.pumpAndSettle();
      return;
    }
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: SearchScreen(
        strings: strings,
        repository: repo,
        authService: auth,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String email = 'user@example.com',
    String password = 'secret6',
  }) async {
    await tester.enterText(find.byKey(const Key('auth_email')), email);
    await tester.enterText(find.byKey(const Key('auth_password')), password);
  }

  testWidgets('بانر الوضع المحلي يظهر ما دامت الخلفية غير مهيأة (ADR-0009 §2)',
      (tester) async {
    final auth = FakeAuthService();
    await pumpSearch(tester, auth);
    expect(find.byKey(const Key('local_mode_banner')), findsOneWidget);
    expect(find.text(strings.get('localModeBanner')), findsOneWidget);
  });

  testWidgets('بريد غير صالح: خطأ فوري وبدون استدعاء الخدمة', (tester) async {
    final auth = FakeAuthService();
    await pumpSearch(tester, auth, useAuthScreen: true);

    await fill(tester, email: 'بريد-بلا-ات');
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_error')), findsOneWidget);
    expect(find.text(strings.get('authInvalidEmail')), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('كلمة مرور قصيرة (5 أحرف): خطأ الحد الأدنى 6 بدون استدعاء',
      (tester) async {
    final auth = FakeAuthService();
    await pumpSearch(tester, auth, useAuthScreen: true);

    await fill(tester, password: 'abcde');
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(find.text(strings.get('authPasswordTooShort')), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('دخول فاشل يعرض رسالة الخدمة ويبقى على النموذج', (tester) async {
    final auth = FakeAuthService();
    auth.failSignIn = true; // اختبار مسار فشل الخدمة، لا الدخول الصحيح.
    await pumpSearch(tester, auth, useAuthScreen: true);

    await fill(tester);
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(find.text(strings.get('authFailed')), findsOneWidget);
    expect(find.byKey(const Key('auth_submit')), findsOneWidget);
    expect(auth.calls, contains('signIn'));
  });

  testWidgets('دخول ناجح يغلق الشاشة', (tester) async {
    final auth = FakeAuthService();
    await pumpSearch(tester, auth, useAuthScreen: true);

    await fill(tester);
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_submit')), findsNothing);
    expect(auth.userId, 'u-test');
  });

  testWidgets('التبديل بين الدخول والتسجيل يبدّل الزر والعنوان', (tester) async {
    final auth = FakeAuthService();
    await pumpSearch(tester, auth, useAuthScreen: true);

    await tester.tap(find.byKey(const Key('auth_switch')));
    await tester.pumpAndSettle();
    expect(find.text(strings.get('authSignUp')), findsWidgets);

    await tester.tap(find.byKey(const Key('auth_switch')));
    await tester.pumpAndSettle();
    expect(find.text(strings.get('authSignIn')), findsWidgets);
  });

  testWidgets('مستخدم مسجّل: الشاشة تظهر الحالة وينهي الجلسة بالخروج',
      (tester) async {
    final auth = FakeAuthService(initialUserId: 'u-test');
    await pumpSearch(tester, auth, useAuthScreen: true);

    expect(find.byKey(const Key('auth_signout')), findsOneWidget);
    expect(find.byKey(const Key('auth_submit')), findsNothing);

    await tester.tap(find.byKey(const Key('auth_signout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_signout')), findsNothing);
    expect(auth.userId, isNull);
    expect(auth.calls, contains('signOut'));
  });
}
