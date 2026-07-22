import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/leaderboard/models/leaderboard.dart';
import 'package:one_minute_ludo/features/leaderboard/models/leaderboard_entry.dart';
import 'package:one_minute_ludo/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:one_minute_ludo/features/leaderboard/services/leaderboard_service.dart';

// ─── Fake ApiClient ───────────────────────────────────────────────────────────

/// Minimal stub that satisfies the LeaderboardService constructor without
/// opening any platform channels.  The service method is overridden in the
/// fake subclass below, so the ApiClient is never actually called.
class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenStorage: const TokenStorage());
}

// ─── Fake LeaderboardService ──────────────────────────────────────────────────

class _FakeLeaderboardService extends LeaderboardService {
  _FakeLeaderboardService(this._impl) : super(apiClient: _FakeApiClient());

  /// Configurable implementation — each test supplies its own behaviour.
  final Future<Leaderboard> Function() _impl;

  /// Number of times [getLeaderboard] has been called.  Used to verify that
  /// Retry and pull-to-refresh each trigger a fresh load.
  int callCount = 0;

  @override
  Future<Leaderboard> getLeaderboard() {
    callCount++;
    return _impl();
  }
}

// ─── Test fixtures ────────────────────────────────────────────────────────────

LeaderboardEntry _makeEntry({
  int    rank     = 1,
  String playerId = 'LUD-A1B2C3',
  String fullName = 'Alice Smith',
  int    wins     = 10,
}) =>
    LeaderboardEntry.fromJson(<String, dynamic>{
      'rank':      rank,
      'player_id': playerId,
      'full_name': fullName,
      'avatar':    null,
      'wins':      wins,
    });

Leaderboard _emptyLeaderboard() => Leaderboard.fromJson(<String, dynamic>{
      'leaderboard': <dynamic>[],
    });

Leaderboard _leaderboardWith(List<LeaderboardEntry> entries) {
  final rawList = entries
      .map((e) => <String, dynamic>{
            'rank':      e.rank,
            'player_id': e.playerId,
            'full_name': e.fullName,
            'avatar':    e.avatar,
            'wins':      e.wins,
          })
      .toList();

  return Leaderboard.fromJson(<String, dynamic>{
    'leaderboard': rawList,
  });
}

// ─── Pump helper ─────────────────────────────────────────────────────────────

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeLeaderboardService service, {
  VoidCallback? onSessionExpired,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LeaderboardScreen(
          leaderboardService: service,
          onSessionExpired:   onSessionExpired ?? () {},
        ),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ─── 1: Smoke ───────────────────────────────────────────────────────────────

  testWidgets('1 — LeaderboardScreen renders without crash', (tester) async {
    final service = _FakeLeaderboardService(
      () => Future.value(_emptyLeaderboard()),
    );

    await _pumpScreen(tester, service);

    expect(find.byType(LeaderboardScreen), findsOneWidget);
  });

  // ─── 2: Loading state ───────────────────────────────────────────────────────

  testWidgets('2 — leaderboard_loading shown while getLeaderboard() is in flight',
      (tester) async {
    final completer = Completer<Leaderboard>();
    final service   = _FakeLeaderboardService(() => completer.future);

    await _pumpScreen(tester, service);
    // Do NOT settle futures — the Completer never completes during this test.

    expect(find.byKey(const Key('leaderboard_loading')), findsOneWidget);
    expect(find.byKey(const Key('leaderboard_error')),   findsNothing);
    expect(find.byKey(const Key('leaderboard_empty')),   findsNothing);
    expect(find.byKey(const Key('leaderboard_list')),    findsNothing);
  });

  // ─── 3: Error state — ApiException ─────────────────────────────────────────

  testWidgets(
      '3 — leaderboard_error shown when getLeaderboard() throws ApiException',
      (tester) async {
    final service = _FakeLeaderboardService(
      () => Future.error(
        const ApiException(statusCode: 500, message: 'Server error'),
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pump(); // allow async error to propagate

    expect(find.byKey(const Key('leaderboard_error')),   findsOneWidget);
    expect(find.byKey(const Key('leaderboard_loading')), findsNothing);
    expect(find.byKey(const Key('leaderboard_empty')),   findsNothing);
    expect(find.byKey(const Key('leaderboard_list')),    findsNothing);
  });

  // ─── 4: Retry button present in error state ─────────────────────────────────

  testWidgets('4 — leaderboard_retry button present in error state',
      (tester) async {
    final service = _FakeLeaderboardService(
      () => Future.error(
        const ApiException(statusCode: 500, message: 'Oops'),
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.byKey(const Key('leaderboard_retry')), findsOneWidget);
  });

  // ─── 5: Retry triggers reload ───────────────────────────────────────────────

  testWidgets('5 — tapping Retry calls getLeaderboard() again', (tester) async {
    final service = _FakeLeaderboardService(
      () => Future.error(
        const ApiException(statusCode: 500, message: 'Oops'),
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pump(); // first error settles

    expect(service.callCount, 1);

    await tester.tap(find.byKey(const Key('leaderboard_retry')));
    await tester.pump(); // second call settles

    expect(service.callCount, 2);
  });

  // ─── 6: Empty state ─────────────────────────────────────────────────────────

  testWidgets('6 — leaderboard_empty shown when entries list is empty',
      (tester) async {
    final service = _FakeLeaderboardService(
      () => Future.value(_emptyLeaderboard()),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.byKey(const Key('leaderboard_empty')),   findsOneWidget);
    expect(find.byKey(const Key('leaderboard_loading')), findsNothing);
    expect(find.byKey(const Key('leaderboard_error')),   findsNothing);
    expect(find.byKey(const Key('leaderboard_list')),    findsNothing);
  });

  // ─── 7: Data state — list shown ─────────────────────────────────────────────

  testWidgets('7 — leaderboard_list shown when entries are present',
      (tester) async {
    final service = _FakeLeaderboardService(
      () => Future.value(_leaderboardWith([_makeEntry()])),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.byKey(const Key('leaderboard_list')),    findsOneWidget);
    expect(find.byKey(const Key('leaderboard_loading')), findsNothing);
    expect(find.byKey(const Key('leaderboard_error')),   findsNothing);
    expect(find.byKey(const Key('leaderboard_empty')),   findsNothing);
  });

  // ─── 8: Correct tile count rendered ─────────────────────────────────────────

  testWidgets('8 — correct number of leaderboard_tile widgets rendered',
      (tester) async {
    final entries = [
      _makeEntry(rank: 1, playerId: 'LUD-AAA', fullName: 'Alice', wins: 30),
      _makeEntry(rank: 2, playerId: 'LUD-BBB', fullName: 'Bob',   wins: 20),
      _makeEntry(rank: 3, playerId: 'LUD-CCC', fullName: 'Carol', wins: 10),
    ];
    final service = _FakeLeaderboardService(
      () => Future.value(_leaderboardWith(entries)),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.byKey(const Key('leaderboard_tile_0')), findsOneWidget);
    expect(find.byKey(const Key('leaderboard_tile_1')), findsOneWidget);
    expect(find.byKey(const Key('leaderboard_tile_2')), findsOneWidget);
  });

  // ─── 9: Player name visible ──────────────────────────────────────────────────

  testWidgets('9 — player full name is visible on tile', (tester) async {
    final service = _FakeLeaderboardService(
      () => Future.value(
        _leaderboardWith([_makeEntry(fullName: 'Zara Khan')]),
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.text('Zara Khan'), findsOneWidget);
  });

  // ─── 10: Win count visible ──────────────────────────────────────────────────

  testWidgets('10 — win count text visible on tile', (tester) async {
    final service = _FakeLeaderboardService(
      () => Future.value(_leaderboardWith([_makeEntry(wins: 42)])),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.text('42'), findsOneWidget);
  });

  // ─── 11: Pull-to-refresh triggers reload ────────────────────────────────────

  testWidgets('11 — pull-to-refresh triggers a second getLeaderboard() call',
      (tester) async {
    final service = _FakeLeaderboardService(
      () => Future.value(_leaderboardWith([_makeEntry()])),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(service.callCount, 1);

    await tester.drag(
      find.byKey(const Key('leaderboard_list')),
      const Offset(0, 300),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.callCount, 2);
  });

  // ─── 12: SessionExpiredException triggers callback ──────────────────────────

  testWidgets(
      '12 — SessionExpiredException triggers onSessionExpired callback',
      (tester) async {
    bool sessionExpiredCalled = false;

    final service = _FakeLeaderboardService(
      () => Future.error(SessionExpiredException()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LeaderboardScreen(
            leaderboardService: service,
            onSessionExpired:   () => sessionExpiredCalled = true,
          ),
        ),
      ),
    );
    await tester.pump(); // allow future to settle

    expect(sessionExpiredCalled, isTrue);
    // Screen does NOT enter error state — session expiry is a routing concern.
    expect(find.byKey(const Key('leaderboard_error')), findsNothing);
  });
}
