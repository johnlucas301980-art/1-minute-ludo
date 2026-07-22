import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/history/models/match_history.dart';
import 'package:one_minute_ludo/features/history/models/match_history_entry.dart';
import 'package:one_minute_ludo/features/history/screens/history_screen.dart';
import 'package:one_minute_ludo/features/history/services/history_service.dart';

// ─── Fake ApiClient ───────────────────────────────────────────────────────────

/// Minimal stub that satisfies the HistoryService constructor without opening
/// any platform channels.  The service method is overridden in the fake
/// subclass below, so the ApiClient is never actually called.
class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenStorage: const TokenStorage());
}

// ─── Fake HistoryService ──────────────────────────────────────────────────────

class _FakeHistoryService extends HistoryService {
  _FakeHistoryService(this._impl) : super(apiClient: _FakeApiClient());

  /// Configurable implementation — each test supplies its own behaviour.
  final Future<MatchHistory> Function() _impl;

  /// Number of times [getHistory] has been called.  Used to verify that
  /// Retry and pull-to-refresh each trigger a fresh load.
  int callCount = 0;

  @override
  Future<MatchHistory> getHistory({int limit = 20, int offset = 0}) {
    callCount++;
    return _impl();
  }
}

// ─── Test fixtures ────────────────────────────────────────────────────────────

MatchOpponent _makeOpponent({String name = 'Opponent Player'}) =>
    MatchOpponent.fromJson(<String, dynamic>{
      'player_id': 'LUD-OPP123',
      'full_name': name,
      'avatar':    null,
    });

MatchHistoryEntry _makeEntry({
  String result       = 'win',
  double earnedPoints = 10.0,
  String matchId      = 'match-uuid-1',
  String opponentName = 'Opponent Player',
}) =>
    MatchHistoryEntry.fromJson(<String, dynamic>{
      'match_id':      matchId,
      'room_code':     'AB3Z9K',
      'mode':          'random',
      'started_at':    '2026-07-22T10:00:00.000Z',
      'finished_at':   '2026-07-22T10:01:00.000Z',
      'result':        result,
      'earned_points': earnedPoints,
      'entry_points':  5.0,
      'opponent': <String, dynamic>{
        'player_id': 'LUD-OPP123',
        'full_name': opponentName,
        'avatar':    null,
      },
    });

MatchHistory _emptyHistory() => MatchHistory.fromJson(<String, dynamic>{
      'matches':    <dynamic>[],
      'pagination': <String, dynamic>{
        'total':  0,
        'limit':  20,
        'offset': 0,
      },
    });

MatchHistory _historyWith(List<MatchHistoryEntry> entries) {
  final rawList = entries
      .map((_) => <String, dynamic>{
            'match_id':      _.matchId,
            'room_code':     _.roomCode,
            'mode':          _.mode,
            'started_at':    _.startedAt,
            'finished_at':   _.finishedAt,
            'result':        _.result,
            'earned_points': _.earnedPoints,
            'entry_points':  _.entryPoints,
            'opponent': <String, dynamic>{
              'player_id': _.opponent.playerId,
              'full_name': _.opponent.fullName,
              'avatar':    _.opponent.avatar,
            },
          })
      .toList();

  return MatchHistory.fromJson(<String, dynamic>{
    'matches':    rawList,
    'pagination': <String, dynamic>{
      'total':  entries.length,
      'limit':  20,
      'offset': 0,
    },
  });
}

// ─── Pump helper ─────────────────────────────────────────────────────────────

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeHistoryService service, {
  VoidCallback? onSessionExpired,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HistoryScreen(
          historyService:    service,
          onSessionExpired:  onSessionExpired ?? () {},
        ),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ─── 1: Smoke ───────────────────────────────────────────────────────────────

  testWidgets('1 — HistoryScreen renders without crash', (tester) async {
    final service = _FakeHistoryService(
      () => Future.value(_emptyHistory()),
    );

    await _pumpScreen(tester, service);

    // Widget tree was built — no exception thrown.
    expect(find.byType(HistoryScreen), findsOneWidget);
  });

  // ─── 2: Loading state ───────────────────────────────────────────────────────

  testWidgets('2 — history_loading shown while getHistory() is in flight',
      (tester) async {
    final completer = Completer<MatchHistory>();
    final service   = _FakeHistoryService(() => completer.future);

    await _pumpScreen(tester, service);
    // Do NOT settle futures — the Completer never completes during this test.

    expect(find.byKey(const Key('history_loading')), findsOneWidget);
    expect(find.byKey(const Key('history_error')),   findsNothing);
    expect(find.byKey(const Key('history_empty')),   findsNothing);
    expect(find.byKey(const Key('history_list')),    findsNothing);
  });

  // ─── 3: Error state — ApiException ─────────────────────────────────────────

  testWidgets('3 — history_error shown when getHistory() throws ApiException',
      (tester) async {
    final service = _FakeHistoryService(
      () => Future.error(
        const ApiException(statusCode: 500, message: 'Server error'),
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pump(); // allow async error to propagate

    expect(find.byKey(const Key('history_error')),   findsOneWidget);
    expect(find.byKey(const Key('history_loading')), findsNothing);
    expect(find.byKey(const Key('history_empty')),   findsNothing);
    expect(find.byKey(const Key('history_list')),    findsNothing);
  });

  // ─── 4: Retry button present in error state ─────────────────────────────────

  testWidgets('4 — history_retry button present in error state', (tester) async {
    final service = _FakeHistoryService(
      () => Future.error(
        const ApiException(statusCode: 500, message: 'Oops'),
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.byKey(const Key('history_retry')), findsOneWidget);
  });

  // ─── 5: Retry triggers reload ───────────────────────────────────────────────

  testWidgets('5 — tapping Retry calls getHistory() again', (tester) async {
    // First call: error. Second call: also error (we just count calls).
    final service = _FakeHistoryService(
      () => Future.error(
        const ApiException(statusCode: 500, message: 'Oops'),
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pump(); // first error settles

    expect(service.callCount, 1);

    await tester.tap(find.byKey(const Key('history_retry')));
    await tester.pump(); // second call settles

    expect(service.callCount, 2);
  });

  // ─── 6: Empty state ─────────────────────────────────────────────────────────

  testWidgets('6 — history_empty shown when entries list is empty',
      (tester) async {
    final service = _FakeHistoryService(
      () => Future.value(_emptyHistory()),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.byKey(const Key('history_empty')),   findsOneWidget);
    expect(find.byKey(const Key('history_loading')), findsNothing);
    expect(find.byKey(const Key('history_error')),   findsNothing);
    expect(find.byKey(const Key('history_list')),    findsNothing);
  });

  // ─── 7: Data state — list shown ─────────────────────────────────────────────

  testWidgets('7 — history_list shown when entries are present', (tester) async {
    final service = _FakeHistoryService(
      () => Future.value(_historyWith([_makeEntry()])),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.byKey(const Key('history_list')),    findsOneWidget);
    expect(find.byKey(const Key('history_loading')), findsNothing);
    expect(find.byKey(const Key('history_error')),   findsNothing);
    expect(find.byKey(const Key('history_empty')),   findsNothing);
  });

  // ─── 8: Correct tile count rendered ─────────────────────────────────────────

  testWidgets('8 — correct number of match_tile widgets rendered',
      (tester) async {
    final entries = [
      _makeEntry(matchId: 'id-1', result: 'win'),
      _makeEntry(matchId: 'id-2', result: 'loss'),
      _makeEntry(matchId: 'id-3', result: 'win'),
    ];
    final service = _FakeHistoryService(
      () => Future.value(_historyWith(entries)),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.byKey(const Key('match_tile_0')), findsOneWidget);
    expect(find.byKey(const Key('match_tile_1')), findsOneWidget);
    expect(find.byKey(const Key('match_tile_2')), findsOneWidget);
  });

  // ─── 9: Win tile uses green icon ────────────────────────────────────────────

  testWidgets('9 — match_result_0 uses green check icon for a win entry',
      (tester) async {
    final service = _FakeHistoryService(
      () => Future.value(_historyWith([_makeEntry(result: 'win')])),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('match_result_0')),
    );
    // The leading CircleAvatar has the green-tinted background colour.
    final Color bg = avatar.backgroundColor!;
    // Green component dominates — check the Icon child directly.
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('match_result_0')),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.check);
    expect(bg.green, greaterThan(bg.red));
  });

  // ─── 10: Loss tile uses red icon ────────────────────────────────────────────

  testWidgets('10 — match_result_0 uses red close icon for a loss entry',
      (tester) async {
    final service = _FakeHistoryService(
      () => Future.value(_historyWith([_makeEntry(result: 'loss')])),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('match_result_0')),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.close);

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('match_result_0')),
    );
    final Color bg = avatar.backgroundColor!;
    expect(bg.red, greaterThan(bg.green));
  });

  // ─── 11: Opponent name visible ──────────────────────────────────────────────

  testWidgets('11 — opponent name text visible on tile', (tester) async {
    final service = _FakeHistoryService(
      () => Future.value(
        _historyWith([_makeEntry(opponentName: 'Alice Smith')]),
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(find.text('Alice Smith'), findsOneWidget);
  });

  // ─── 12: Earned points visible ──────────────────────────────────────────────

  testWidgets('12 — earned points text visible on tile', (tester) async {
    final service = _FakeHistoryService(
      () => Future.value(_historyWith([_makeEntry(earnedPoints: 15.0)])),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    // Win entry → +15.0
    expect(find.text('+15.0'), findsOneWidget);
  });

  // ─── 13: Pull-to-refresh triggers reload ───────────────────────────────────

  testWidgets('13 — pull-to-refresh triggers a second getHistory() call',
      (tester) async {
    final service = _FakeHistoryService(
      () => Future.value(_historyWith([_makeEntry()])),
    );

    await _pumpScreen(tester, service);
    await tester.pump();

    expect(service.callCount, 1);

    // Drag down to trigger the RefreshIndicator.
    await tester.drag(find.byKey(const Key('history_list')), const Offset(0, 300));
    await tester.pump();        // start the drag animation
    await tester.pump(const Duration(seconds: 1)); // complete refresh

    expect(service.callCount, 2);
  });

  // ─── 14: SessionExpiredException triggers callback ──────────────────────────

  testWidgets('14 — SessionExpiredException triggers onSessionExpired callback',
      (tester) async {
    bool sessionExpiredCalled = false;

    final service = _FakeHistoryService(
      () => Future.error(SessionExpiredException()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryScreen(
            historyService:   service,
            onSessionExpired: () => sessionExpiredCalled = true,
          ),
        ),
      ),
    );
    await tester.pump(); // allow future to settle

    expect(sessionExpiredCalled, isTrue);
    // Screen does NOT enter error state — session expiry is a routing concern.
    expect(find.byKey(const Key('history_error')), findsNothing);
  });
}
