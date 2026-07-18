import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/auth/models/user_profile.dart';
import 'package:one_minute_ludo/features/auth/screens/register_screen.dart';
import 'package:one_minute_ludo/features/auth/services/auth_service.dart';

// ─── Test fixture ─────────────────────────────────────────────────────────────

const _kProfile = UserProfile(
  id: 'user-uuid-2',
  playerId: 'LUD-XYZ789',
  fullName: 'New Player',
  status: 'active',
  createdAt: '2026-07-18T00:00:00.000Z',
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
    UserProfile registerResponse = _kProfile,
    Exception? registerError,
  })  : _registerResponse = registerResponse,
        _registerError = registerError,
        super(
          apiClient: _FakeApiClient(),
          tokenStorage: const TokenStorage(),
        );

  final UserProfile _registerResponse;
  final Exception? _registerError;

  @override
  Future<UserProfile> register({
    required String fullName,
    required String password,
    String? email,
    String? mobile,
    String? country,
  }) async {
    if (_registerError != null) throw _registerError;
    return _registerResponse;
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
  Future<UserProfile> register({
    required String fullName,
    required String password,
    String? email,
    String? mobile,
    String? country,
  }) =>
      Completer<UserProfile>().future; // never resolves
}

// ─── Fake AuthService — captures call arguments ───────────────────────────────

class _CapturingAuthService extends AuthService {
  _CapturingAuthService()
      : super(
          apiClient: _FakeApiClient(),
          tokenStorage: const TokenStorage(),
        );

  String? capturedFullName;
  String? capturedEmail;
  String? capturedMobile;
  String? capturedPassword;

  @override
  Future<UserProfile> register({
    required String fullName,
    required String password,
    String? email,
    String? mobile,
    String? country,
  }) async {
    capturedFullName = fullName;
    capturedPassword = password;
    capturedEmail = email;
    capturedMobile = mobile;
    return _kProfile;
  }
}

// ─── Widget pump helper ───────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  required AuthService authService,
  void Function(UserProfile)? onRegisterSuccess,
  VoidCallback? onLoginPressed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RegisterScreen(
        authService: authService,
        onRegisterSuccess: onRegisterSuccess ?? (_) {},
        onLoginPressed: onLoginPressed ?? () {},
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── 1: Smoke — renders without crashing ──────────────────────────────────
  testWidgets(
    'RegisterScreen 1 — renders without crashing',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byType(RegisterScreen), findsOneWidget);
    },
  );

  // ── 2: Full Name field is present ────────────────────────────────────────
  testWidgets(
    'RegisterScreen 2 — full name field is rendered',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byKey(const Key('full_name_field')), findsOneWidget);
    },
  );

  // ── 3: Email field is present ────────────────────────────────────────────
  testWidgets(
    'RegisterScreen 3 — email field is rendered',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byKey(const Key('email_field')), findsOneWidget);
    },
  );

  // ── 4: Mobile field is present ───────────────────────────────────────────
  testWidgets(
    'RegisterScreen 4 — mobile field is rendered',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byKey(const Key('mobile_field')), findsOneWidget);
    },
  );

  // ── 5: Password field is present ─────────────────────────────────────────
  testWidgets(
    'RegisterScreen 5 — password field is rendered',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byKey(const Key('password_field')), findsOneWidget);
    },
  );

  // ── 6: Register button is present ────────────────────────────────────────
  testWidgets(
    'RegisterScreen 6 — Register button is rendered',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());
      expect(find.byKey(const Key('register_button')), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
    },
  );

  // ── 7: Empty full name shows validation message ───────────────────────────
  testWidgets(
    'RegisterScreen 7 — tapping Register with empty full name shows validation message',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());

      // Tap without entering any text.
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pump();

      expect(find.text('Please enter your full name.'), findsOneWidget);
    },
  );

  // ── 8: Empty password shows validation message ────────────────────────────
  testWidgets(
    'RegisterScreen 8 — tapping Register with empty password shows validation message',
    (tester) async {
      await _pump(tester, authService: _FakeAuthService());

      await tester.enterText(
        find.byKey(const Key('full_name_field')),
        'New Player',
      );
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pump();

      expect(find.text('Please enter a password.'), findsOneWidget);
    },
  );

  // ── 9: Successful registration calls onRegisterSuccess ────────────────────
  testWidgets(
    'RegisterScreen 9 — successful registration calls onRegisterSuccess with UserProfile',
    (tester) async {
      UserProfile? received;

      await _pump(
        tester,
        authService: _FakeAuthService(),
        onRegisterSuccess: (profile) => received = profile,
      );

      await tester.enterText(
        find.byKey(const Key('full_name_field')),
        'New Player',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'Secret123',
      );
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pump(); // future resolves
      await tester.pump(); // setState + callback

      expect(received, isNotNull);
      expect(received!.playerId, 'LUD-XYZ789');
    },
  );

  // ── 10: ApiException (400) shows error banner ─────────────────────────────
  testWidgets(
    'RegisterScreen 10 — ApiException (400) from register shows error banner',
    (tester) async {
      await _pump(
        tester,
        authService: _FakeAuthService(
          registerError: const ApiException(
            statusCode: 400,
            message: 'Password must be at least 8 characters.',
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('full_name_field')),
        'New Player',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'short',
      );
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters.'),
        findsOneWidget,
      );
    },
  );

  // ── 11: ApiException (409) shows error banner ─────────────────────────────
  testWidgets(
    'RegisterScreen 11 — ApiException (409) from register shows conflict error banner',
    (tester) async {
      await _pump(
        tester,
        authService: _FakeAuthService(
          registerError: const ApiException(
            statusCode: 409,
            message: 'An account with this email already exists.',
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('full_name_field')),
        'New Player',
      );
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'taken@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'Secret123',
      );
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );
    },
  );

  // ── 12: Loading spinner shown while registration is in progress ───────────
  testWidgets(
    'RegisterScreen 12 — loading spinner shown while registration is in progress',
    (tester) async {
      await _pump(
        tester,
        authService: _NeverResolvingAuthService(),
      );

      await tester.enterText(
        find.byKey(const Key('full_name_field')),
        'New Player',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'Secret123',
      );

      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pump(); // _submit() starts, setState(submitting=true)

      // Button is disabled and replaced with a spinner.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsNothing);
    },
  );

  // ── 13: onLoginPressed callback fired when Log in link tapped ─────────────
  testWidgets(
    'RegisterScreen 13 — tapping the Log in link fires onLoginPressed',
    (tester) async {
      var pressed = false;

      await _pump(
        tester,
        authService: _FakeAuthService(),
        onLoginPressed: () => pressed = true,
      );

      await tester.tap(find.byKey(const Key('login_link')));
      await tester.pump();

      expect(pressed, isTrue);
    },
  );

  // ── 14: Password visibility toggle ───────────────────────────────────────
  testWidgets(
    'RegisterScreen 14 — password visibility toggle changes the obscure icon',
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

  // ── 15: Blank email and mobile → service called without them ──────────────
  testWidgets(
    'RegisterScreen 15 — blank optional fields are not passed to the service',
    (tester) async {
      final capturing = _CapturingAuthService();

      await _pump(tester, authService: capturing);

      await tester.enterText(
        find.byKey(const Key('full_name_field')),
        'New Player',
      );
      // Leave email and mobile blank.
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'Secret123',
      );
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pump();
      await tester.pump();

      expect(capturing.capturedEmail, isNull);
      expect(capturing.capturedMobile, isNull);
      expect(capturing.capturedFullName, 'New Player');
    },
  );
}
