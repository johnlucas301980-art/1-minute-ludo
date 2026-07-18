import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/auth/models/user_profile.dart';
import 'package:one_minute_ludo/features/profile/screens/profile_screen.dart';
import 'package:one_minute_ludo/features/profile/services/change_password_service.dart';
import 'package:one_minute_ludo/features/profile/services/profile_service.dart';

// ─── Test profile fixture ─────────────────────────────────────────────────────

const _kProfile = UserProfile(
  id: 'user-uuid-1',
  playerId: 'LUD-ABC123',
  fullName: 'Test Player',
  email: 'test@example.com',
  mobile: '+2348012345678',
  country: 'NG',
  status: 'active',
  createdAt: '2026-07-15T00:00:00.000Z',
  updatedAt: '2026-07-18T10:00:00.000Z',
);

// ─── Fake ApiClient ───────────────────────────────────────────────────────────

/// Minimal stub that satisfies the ProfileService / ChangePasswordService
/// constructor without opening any platform channels.  The service methods
/// are overridden in the fake subclasses below, so the ApiClient is never
/// actually called.
class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenStorage: const TokenStorage());
}

// ─── Fake ProfileService ──────────────────────────────────────────────────────

class _FakeProfileService extends ProfileService {
  _FakeProfileService({
    UserProfile getResponse = _kProfile,
    UserProfile? updateResponse,
    Exception? getError,
  })  : _getResponse = getResponse,
        _updateResponse = updateResponse ?? getResponse,
        _getError = getError,
        super(apiClient: _FakeApiClient());

  final UserProfile _getResponse;
  final UserProfile _updateResponse;
  final Exception? _getError;

  @override
  Future<UserProfile> getProfile() async {
    if (_getError != null) throw _getError;
    return _getResponse;
  }

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    Object? country = const Object(),
    Object? avatar = const Object(),
  }) async {
    return _updateResponse;
  }
}

// ─── Fake ChangePasswordService ───────────────────────────────────────────────

class _FakeChangePasswordService extends ChangePasswordService {
  _FakeChangePasswordService({Exception? error})
      : _error = error,
        super(apiClient: _FakeApiClient());

  final Exception? _error;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_error != null) throw _error;
  }
}

// ─── Widget pump helper ───────────────────────────────────────────────────────

/// Wraps [ProfileScreen] in a [MaterialApp] and pumps it.
Future<void> _pump(
  WidgetTester tester, {
  required ProfileService profileService,
  required ChangePasswordService changePasswordService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileScreen(
        profileService: profileService,
        changePasswordService: changePasswordService,
      ),
    ),
  );
}

/// Flushes the async chain from initState (one microtask hop per await in the
/// fake service, then one frame rebuild).  Three pump() calls are sufficient
/// for the fake implementations.  We avoid pumpAndSettle() here because the
/// AnimatedSwitcher's outgoing child may briefly show a CircularProgressIndicator
/// whose continuous animation never settles.
Future<void> _pumpLoaded(WidgetTester tester) async {
  await tester.pump(); // schedules microtask
  await tester.pump(); // fake getProfile() resolves → setState
  await tester.pump(const Duration(milliseconds: 300)); // AnimatedSwitcher
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── 1: Smoke — renders without crashing ──────────────────────────────────
  testWidgets(
    'ProfileScreen 1 — renders without crashing (initial loading state)',
    (tester) async {
      await _pump(
        tester,
        profileService: _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
      );
      // Before any pump the screen is in its initial state (loading widget built).
      expect(find.byType(ProfileScreen), findsOneWidget);
    },
  );

  // ── 2: Loading indicator shown initially ──────────────────────────────────
  testWidgets(
    'ProfileScreen 2 — shows CircularProgressIndicator before data arrives',
    (tester) async {
      await _pump(
        tester,
        profileService: _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
      );
      // On the very first frame the initState future has not yet resolved.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test Player'), findsNothing);
    },
  );

  // ── 3: Profile data displayed after load ─────────────────────────────────
  testWidgets(
    'ProfileScreen 3 — displays player data after successful load',
    (tester) async {
      await _pump(
        tester,
        profileService: _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
      );
      await _pumpLoaded(tester);

      expect(find.text('Test Player'), findsOneWidget);
      expect(find.text('LUD-ABC123'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('+2348012345678'), findsOneWidget);
      expect(find.text('NG'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget); // status badge
    },
  );

  // ── 4: Error state shown when load fails ──────────────────────────────────
  testWidgets(
    'ProfileScreen 4 — shows error state when profile load fails',
    (tester) async {
      await _pump(
        tester,
        profileService: _FakeProfileService(
          getError: const ApiException(
            statusCode: 500,
            message: 'Server is unavailable.',
          ),
        ),
        changePasswordService: _FakeChangePasswordService(),
      );
      await _pumpLoaded(tester);

      expect(find.text('Could not load profile'), findsOneWidget);
      expect(find.text('Server is unavailable.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Test Player'), findsNothing);
    },
  );

  // ── 5: Retry reloads profile ──────────────────────────────────────────────
  testWidgets(
    'ProfileScreen 5 — Retry button reloads and shows profile on success',
    (tester) async {
      // First call throws; subsequent calls succeed.
      var callCount = 0;
      // We need a service whose getProfile() behaviour changes between calls.
      // Subclass inline to capture callCount.
      final profileService = _CountingProfileService(failFirst: true);

      await _pump(
        tester,
        profileService: profileService,
        changePasswordService: _FakeChangePasswordService(),
      );
      await _pumpLoaded(tester);

      expect(find.text('Retry'), findsOneWidget);
      callCount = profileService.callCount;

      await tester.tap(find.text('Retry'));
      await _pumpLoaded(tester);

      expect(profileService.callCount, greaterThan(callCount));
      expect(find.text('Test Player'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );

  // ── 6: Edit Profile button opens Edit Profile sheet ───────────────────────
  testWidgets(
    'ProfileScreen 6 — tapping "Edit Profile" opens the Edit Profile sheet',
    (tester) async {
      await _pump(
        tester,
        profileService: _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
      );
      await _pumpLoaded(tester);

      final editBtn = find.byKey(const Key('edit_profile_button'));
      await tester.ensureVisible(editBtn);
      await tester.pump();
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Sheet title and save button confirm the sheet is open.
      expect(find.text('Save Changes'), findsOneWidget);
      // Full-name field should be pre-filled.
      expect(find.text('Test Player'), findsWidgets);
    },
  );

  // ── 7: Change Password button opens Change Password sheet ─────────────────
  testWidgets(
    'ProfileScreen 7 — tapping "Change Password" opens the Change Password sheet',
    (tester) async {
      await _pump(
        tester,
        profileService: _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
      );
      await _pumpLoaded(tester);

      final changeBtn = find.byKey(const Key('change_password_button'));
      await tester.ensureVisible(changeBtn);
      await tester.pump();
      await tester.tap(changeBtn);
      await tester.pumpAndSettle();

      // All three password fields must be visible inside the sheet.
      expect(find.byType(TextFormField), findsNWidgets(3));
      // The sheet's ElevatedButton submit must be visible.
      expect(
        find.widgetWithText(ElevatedButton, 'Change Password'),
        findsOneWidget,
      );
    },
  );

  // ── 8: Pull-to-refresh reloads profile ────────────────────────────────────
  testWidgets(
    'ProfileScreen 8 — pull-to-refresh triggers a second getProfile call',
    (tester) async {
      final profileService = _CountingProfileService(failFirst: false);

      await _pump(
        tester,
        profileService: profileService,
        changePasswordService: _FakeChangePasswordService(),
      );
      await _pumpLoaded(tester);

      expect(find.text('Test Player'), findsOneWidget);
      final countBefore = profileService.callCount;

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 300),
      );
      await tester.pump();
      await _pumpLoaded(tester);

      expect(profileService.callCount, greaterThan(countBefore));
    },
  );

  // ── 9: Edit Profile sheet saves and updates the screen ────────────────────
  testWidgets(
    'ProfileScreen 9 — Edit Profile sheet submits and the screen shows '
    'the updated profile',
    (tester) async {
      const updated = UserProfile(
        id: 'user-uuid-1',
        playerId: 'LUD-ABC123',
        fullName: 'New Name',
        email: 'test@example.com',
        status: 'active',
        createdAt: '2026-07-15T00:00:00.000Z',
      );

      await _pump(
        tester,
        profileService: _FakeProfileService(updateResponse: updated),
        changePasswordService: _FakeChangePasswordService(),
      );
      await _pumpLoaded(tester);

      // Open the Edit Profile sheet.
      final editBtn9 = find.byKey(const Key('edit_profile_button'));
      await tester.ensureVisible(editBtn9);
      await tester.pump();
      await tester.tap(editBtn9);
      await tester.pumpAndSettle();

      // The Full Name field is the first TextFormField in the sheet.
      final nameField = find.byType(TextFormField).first;
      await tester.ensureVisible(nameField);
      await tester.pump();
      await tester.enterText(nameField, 'New Name');
      await tester.pump();

      // Submit.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pump(); // fake updateProfile resolves
      await tester.pump(); // setState with updated profile
      await tester.pumpAndSettle(); // sheet dismiss animation

      expect(find.text('Save Changes'), findsNothing);
      expect(find.text('New Name'), findsOneWidget);
    },
  );

  // ── 10: Change Password sheet shows wrong-password error inline ───────────
  testWidgets(
    'ProfileScreen 10 — Change Password sheet shows wrong-password inline '
    'error without closing the session',
    (tester) async {
      await _pump(
        tester,
        profileService: _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(
          error: WrongCurrentPasswordException(),
        ),
      );
      await _pumpLoaded(tester);

      // Open the Change Password sheet.
      final cpBtn10 = find.byKey(const Key('change_password_button'));
      await tester.ensureVisible(cpBtn10);
      await tester.pump();
      await tester.tap(cpBtn10);
      await tester.pumpAndSettle();

      // Sheet has three TextFormFields.
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3));

      await tester.enterText(fields.at(0), 'WrongPass1');
      await tester.pump();
      await tester.enterText(fields.at(1), 'NewPass99');
      await tester.pump();
      await tester.enterText(fields.at(2), 'NewPass99');
      await tester.pump();

      // Submit — fake service throws WrongCurrentPasswordException.
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Change Password'),
      );
      await tester.pump(); // exception caught, setState
      await tester.pump(); // _formKey.validate() re-render
      await tester.pump(const Duration(milliseconds: 50));

      // Inline field error must appear.
      expect(find.text('Current password is incorrect.'), findsOneWidget);
      // Sheet stays open.
      expect(find.byType(TextFormField), findsNWidgets(3));
    },
  );
}

// ─── Helper: counting profile service ────────────────────────────────────────

/// A [ProfileService] fake that counts [getProfile] calls and optionally
/// fails the first call to exercise the retry logic (test 5).
class _CountingProfileService extends ProfileService {
  _CountingProfileService({required this.failFirst})
      : super(apiClient: _FakeApiClient());

  final bool failFirst;
  int callCount = 0;

  @override
  Future<UserProfile> getProfile() async {
    callCount += 1;
    if (failFirst && callCount == 1) {
      throw const ApiException(statusCode: 500, message: 'Temporary failure.');
    }
    return _kProfile;
  }

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    Object? country = const Object(),
    Object? avatar = const Object(),
  }) async =>
      _kProfile;
}
