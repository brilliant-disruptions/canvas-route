import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../supabase_client.dart';

/// Every device gets a real auth.uid immediately via anonymous sign-in, so RLS
/// works from the first launch. Community features require upgrading that
/// anonymous user to a real account (email or OAuth), which keeps the uid and
/// therefore all routes and visits.
class AuthRepository {
  Stream<AuthState> get changes => sb.auth.onAuthStateChange;
  User? get user => sb.auth.currentUser;
  bool get isSignedIn => user != null;
  bool get isAnonymous => user?.isAnonymous ?? true;

  Future<void> ensureSession() async {
    if (sb.auth.currentSession != null) return;
    await sb.auth.signInAnonymously();
  }

  /// Magic link. For an anonymous user this links the email to the same uid.
  Future<void> sendMagicLink(String email) async {
    if (isSignedIn && isAnonymous) {
      await sb.auth.updateUser(UserAttributes(email: email), emailRedirectTo: Env.authRedirect);
    } else {
      await sb.auth.signInWithOtp(email: email, emailRedirectTo: Env.authRedirect);
    }
  }

  Future<void> verifyEmailOtp(String email, String token) async {
    await sb.auth.verifyOTP(
      email: email,
      token: token,
      type: isSignedIn && isAnonymous ? OtpType.emailChange : OtpType.magiclink,
    );
  }

  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    if (isSignedIn && isAnonymous) {
      return sb.auth.linkIdentity(provider, redirectTo: Env.authRedirect);
    }
    return sb.auth.signInWithOAuth(provider, redirectTo: Env.authRedirect);
  }

  Future<void> signOut() => sb.auth.signOut();

  /// Permanently deletes the account and its data (delete-account edge function),
  /// then signs out. Store rules require deletion in the app, not just deactivation.
  Future<void> deleteAccount() async {
    final res = await sb.functions.invoke('delete-account');
    final data = res.data;
    if (data is! Map || data['deleted'] != true) {
      throw StateError(data is Map && data['error'] is String ? data['error'] as String : 'Couldn\'t delete the account');
    }
    await sb.auth.signOut();
  }
}
