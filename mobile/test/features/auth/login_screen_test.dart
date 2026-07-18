import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/auth/models/user_profile.dart';
import 'package:one_minute_ludo/features/auth/screens/login_screen.dart';
import 'package:one_minute_ludo/features/auth/services/auth_service.dart';

// ─── Test fixture ─────────────────────────────────────────────────────────────

const _kProfile = UserProfile(
  id: 'user-uuid-1',
  playerId: 'LUD-ABC123',
  fullName: 'Test Player',
  email: 'test@example.com',
  status: 'active',
  createdAt: '2026-07-15T00:00:00.000Z',
);

// ─── Fake ApiClient ───────────────────────────────────────────────────────────

/// Minimal stub that satisfies the AuthService constructor without opening
/// any platform channels.  Service methods are overridden in the fakes below,
/// so the ApiClient is never actually invoked.
class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenStorage: const TokenStorage());
}

// ─── Fake AuthService — configurable responses ────────────────────────────────

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    UserProfile loginResponse = _kProfile,
    Exception? loginError,
  })  : _loginResponse = loginResponse,
        _loginError = loginError,
        super(
          apiClient: _FakeApiClient(),
          tokenStorage: const TokenStorage(),
        );

  final UserProfile _loginResponse;
  final Exception? _loginError;

  @override
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) async {
    if (_loginError != null) throw _loginError;
    return _loginResponse;
  }
}

// ─── Fake AuthService — never resolves (loading-state tests) ─────────────────

class _NeverResolvingAuthService extends AuthService {
  _NeverResolvingAuthService()
      : super(
          apiClient: _FakeApiClient(),
          tokenStorage: const TokenStorage(),
        );

  @override
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) =>
      Completer<UserProfile>().future; // never resolves
}

// ─── Widget pump helper ───────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  required AuthService authService,
  void Function(UserProfile)? onLoginSuccess,
  VoidCallback? onRegisterPressed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LoginScreen(
        authService: authService,
        onLoginSuccess: onLoginSuccess ?? (_) {},
        onRegisterPressed: onRegisterPressed ?? () {},
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── 1: Smoke — renders without crashing ──────────────────────────────────
  testWidgets(
    'LoginScreen 1 — renders without crashing',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  // ── 2: Identifier field is present ───────────────────────────────────────
  testWidgets(
    'LoginScreen 2 — identifier field is rendered',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byKey(const Key('identifier_field')), findsOneWidget);
    },
  );

  // ── 3: Password field is present ─────────────────────────────────────────
  testWidgets(
    'LoginScreen 3 — password field is rendered',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byKey(const Key('password_field')), findsOneWidget);
    },
  );

  // ── 4: Log In button is present ──────────────────────────────────────────
  testWidgets(
    'LoginScreen 4 — Log In button is rendered',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byKey(const Key('login_button')), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Log In'), findsOneWidget);
    },
  );

  // ── 5: Empty identifier shows validation message ──────────────────────────
  testWidgets(
    'LoginScreen 5 — tapping Log In with empty identifier shows validation message',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());

      // Tap without entering any text.
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();

      expect(
        find.text('Please enter your email or mobile number.'),
        findsOneWidget,
      );
    },
  );

  // ── 6: Empty password shows validation message ────────────────────────────
  testWidgets(
    'LoginScreen 6 — tapping Log In with empty password shows validation message',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());

      await tester.enterText(
        find.byKey(const Key('identifier_field')),
        'test@example.com',
      );
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();

      expect(find.text('Please enter your password.'), findsOneWidget);
    },
  );

  // ── 7: Successful login calls onLoginSuccess ──────────────────────────────
  testWidgets(
    'LoginScreen 7 — successful login calls onLoginSuccess with UserProfile',
    (tester) async {
      UserProfile? received;

      await _pump(
        tester,
        authService: _FakeAuthService(),
        onLoginSuccess: (profile) => received = profile,
      );

      await tester.enterText(
        find.byKey(const Key('identifier_field')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'Secret123',
      );
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump(); // future resolves
      await tester.pump(); // setState + callback

      expect(received, isNotNull);
      expect(received!.playerId, 'LUD-ABC123');
    },
  );

  // ── 8: ApiException shows error banner ───────────────────────────────────
  testWidgets(
    'LoginScreen 8 — ApiException from login shows error banner with message',
    (tester) async {
      await _pump(
        tester,
        authService: _FakeAuthService(
          loginError: const ApiException(
            statusCode: 401,
            message: 'Invalid credentials.',
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('identifier_field')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'WrongPass',
      );
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Invalid credentials.'), findsOneWidget);
    },
  );

  // ── 9: AccountForbiddenException shows error banner ──────────────────────
  testWidgets(
    'LoginScreen 9 — AccountForbiddenException shows error banner with message',
    (tester) async {
      await _pump(
        tester,
        authService: _FakeAuthService(
          loginError: const AccountForbiddenException(
            message: 'Your account has been suspended.',
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('identifier_field')),
        'banned@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'AnyPass1',
      );
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Your account has been suspended.'),
        findsOneWidget,
      );
    },
  );

  // ── 10: Loading spinner shown while login is in progress ─────────────────
  testWidgets(
    'LoginScreen 10 — loading spinner shown while login is in progress',
    (tester) async {
      await _pump(
        tester,
        authService: _NeverResolvingAuthService(),
      );

      await tester.enterText(
        find.byKey(const Key('identifier_field')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'Secret123',
      );

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump(); // _submit() starts, setState(submitting=true)

      // Button is disabled and replaced with a spinner.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Log In'), findsNothing);
    },
  );

  // ── 11: onRegisterPressed callback fired when Register link tapped ────────
  testWidgets(
    'LoginScreen 11 — tapping the Register link fires onRegisterPressed',
    (tester) async {
      var pressed = false;

      await _pump(
        tester,
        authService: _FakeAuthService(),
        onRegisterPressed: () => pressed = true,
      );

      await tester.tap(find.byKey(const Key('register_link')));
      await tester.pump();

      expect(pressed, isTrue);
    },
  );

  // ── 12: Password visibility toggle ───────────────────────────────────────
  testWidgets(
    'LoginScreen 12 — password visibility toggle changes the obscure icon',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());

      // Initially obscured — visibility icon shown to reveal the password.
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      // Now unobscured — visibility_off icon shown to hide the password.
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    },
  );
}
