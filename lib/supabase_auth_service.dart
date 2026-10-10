import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService extends ChangeNotifier {
  SupabaseAuthService(this.client) {
    _subscription = client.auth.onAuthStateChange.listen((state) {
      // A cached initial session needs server verification before opening home.
      if (state.event == AuthChangeEvent.initialSession) return;
      final session = client.auth.currentSession;
      if (session == null || session.user.id != _account?['id']) {
        _setUser(null);
      } else if (state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.userUpdated) {
        _setUser(session.user);
      }
    }, onError: (Object error, StackTrace stack) => _setUser(null));
  }

  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;
  Map<String, dynamic>? _account;
  bool busy = false;

  Map<String, dynamic>? get account {
    final session = client.auth.currentSession;
    if (session == null ||
        session.isExpired ||
        session.user.id != _account?['id']) {
      return null;
    }
    return _account;
  }

  void _setUser(User? user) {
    final session = client.auth.currentSession;
    if (user == null ||
        session == null ||
        session.isExpired ||
        user.id != session.user.id) {
      _account = null;
    } else {
      final name = user.userMetadata?['name'];
      _account = {
        'id': user.id,
        'email': user.email,
        'name': name is String && name.trim().isNotEmpty ? name.trim() : '보호자',
      };
    }
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) throw Exception('인증 처리 중입니다. 잠시 기다려 주세요.');
    busy = true;
    try {
      await action();
    } on AuthException catch (error) {
      // Do not expose server response bodies, credentials or tokens in the UI.
      throw Exception(switch (error.code) {
        'invalid_credentials' => '이메일 또는 비밀번호가 올바르지 않습니다.',
        'email_not_confirmed' => '이메일 인증을 마친 뒤 로그인해 주세요.',
        'over_request_rate_limit' ||
        'over_email_send_rate_limit' => '요청이 많습니다. 잠시 후 다시 시도해 주세요.',
        _ => '인증하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.',
      });
    } catch (_) {
      throw Exception('인증하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.');
    } finally {
      busy = false;
    }
  }

  Future<void> restore() => _run(() async {
    if (client.auth.currentSession == null) {
      _setUser(null);
      return;
    }
    try {
      if (client.auth.currentSession!.isExpired) {
        await client.auth.refreshSession();
      }
      final response = await client.auth.getUser();
      _setUser(response.user);
    } on AuthException catch (error) {
      _setUser(null);
      if (error.statusCode == '401' ||
          error.statusCode == '403' ||
          {
            'refresh_token_not_found',
            'refresh_token_already_used',
            'session_not_found',
            'user_not_found',
            'bad_jwt',
          }.contains(error.code)) {
        await client.auth.signOut(scope: SignOutScope.local);
        return;
      }
      rethrow;
    } catch (_) {
      _setUser(null);
      rethrow;
    }
  });

  Future<void> login(String email, String password) => _run(() async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _setUser(response.user);
    if (account == null) throw StateError('No valid Auth session returned.');
  });

  Future<void> logout() => _run(() async {
    try {
      // Revoke this device's refresh session; other devices remain signed in.
      await client.auth.signOut(scope: SignOutScope.local);
    } finally {
      _setUser(null);
    }
  });

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
