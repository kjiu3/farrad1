import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/app_backend.dart';

/// نتيجة دخول/تسجيل موحدة للواجهة — لا استثناءات عبر حد الواجهة.
class AuthOutcome {
  const AuthOutcome({required this.ok, this.userId, this.errorKey});

  final bool ok;
  final String? userId;
  final String? errorKey;
}

/// تجريد الجلسة بنمط واجهة `RecipeRepository`: حقن للاختبار (AGENTS §2.1).
/// التنفيذ الإنتاجي يُجرَّب حيًّا بعد مفاتيح المشروع من المالك؛ حتى
/// حينها يبقى مسار gotrue الحي «لم يُختبر بعد» (AGENTS §4.1) —
/// الاختبارات هنا تغطي الواجهة والفروع بلا شبكة.
abstract class AuthService {
  String? get userId;

  Future<AuthOutcome> signIn(String email, String password);
  Future<AuthOutcome> signUp(String email, String password);
  Future<void> signOut();
}

/// التنفيذ الإنتاجي فوق gotrue عبر عميل [AppBackend].
class SupabaseAuthService implements AuthService {
  const SupabaseAuthService();

  @override
  String? get userId => AppBackend.clientOrNull?.auth.currentUser?.id;

  @override
  Future<AuthOutcome> signIn(String email, String password) => _call(
        () => AppBackend.clientOrNull!.auth
            .signInWithPassword(email: email, password: password),
      );

  @override
  Future<AuthOutcome> signUp(String email, String password) =>
      _call(() => AppBackend.clientOrNull!.auth.signUp(
            email: email,
            password: password,
          ));

  @override
  Future<void> signOut() async {
    final auth = AppBackend.clientOrNull?.auth;
    if (auth != null) await auth.signOut();
  }

  Future<AuthOutcome> _call(Future<AuthResponse> Function() action) async {
    try {
      final response = await action();
      final user = response.user;
      if (user == null) {
        // على تأكيد البريد المفعّل قد يعيد signUp بلا مستخدم —
        // تعامَل بلا جلسة (السلوك الحي يُثبت بعد المفاتيح).
        return const AuthOutcome(ok: false, errorKey: 'authFailed');
      }
      return AuthOutcome(ok: true, userId: user.id);
    } on AuthException {
      return const AuthOutcome(ok: false, errorKey: 'authFailed');
    }
  }
}
