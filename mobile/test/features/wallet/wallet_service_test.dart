import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/wallet/services/wallet_service.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Canonical wallet JSON as returned by GET /api/wallet.
final _walletJson = {
  'id': 'wallet-uuid-1',
  'points': 0.0,
  'total_deposit': 0.0,
  'total_withdraw': 0.0,
  'updated_at': '2026-07-18T00:00:00.000Z',
};

/// Canonical transaction JSON as returned within GET /api/wallet/history.
final _txJson = {
  'id': 'tx-uuid-1',
  'type': 'reward',
  'amount': 50.0,
  'status': 'completed',
  'reference': null,
  'created_at': '2026-07-18T12:00:00.000Z',
};

/// A wallet response with optional field overrides.
http.Response _walletResponse({Map<String, dynamic>? overrides}) {
  final wallet = {..._walletJson, ...?overrides};
  return _jsonResponse({'success': true, 'data': {'wallet': wallet}});
}

/// A history response wrapping the given list of transactions.
http.Response _historyResponse({
  List<Map<String, dynamic>>? transactions,
  int limit = 20,
  int offset = 0,
}) {
  final txs = transactions ?? [];
  return _jsonResponse({
    'success': true,
    'data': {
      'transactions': txs,
      'pagination': {
        'limit': limit,
        'offset': offset,
        'count': txs.length,
      },
    },
  });
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late WalletService walletService;

  void buildServices(http.Client mockHttpClient) {
    tokenStorage = const TokenStorage();
    apiClient = ApiClient(tokenStorage: tokenStorage, httpClient: mockHttpClient);
    walletService = WalletService(apiClient: apiClient);
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'valid-access-token',
    });
  });

  // ─── WalletService.getWallet ──────────────────────────────────────────────

  group('WalletService.getWallet', () {
    test('1 — returns Wallet with all fields on success', () async {
      buildServices(MockClient((_) async => _walletResponse()));

      final wallet = await walletService.getWallet();

      expect(wallet.id, 'wallet-uuid-1');
      expect(wallet.points, 0.0);
      expect(wallet.totalDeposit, 0.0);
      expect(wallet.totalWithdraw, 0.0);
      expect(wallet.updatedAt, '2026-07-18T00:00:00.000Z');
    });

    test('2 — non-zero balance is parsed correctly', () async {
      buildServices(MockClient((_) async => _walletResponse(overrides: {
            'points': 250.5,
            'total_deposit': 500.0,
            'total_withdraw': 249.5,
          })));

      final wallet = await walletService.getWallet();

      expect(wallet.points, 250.5);
      expect(wallet.totalDeposit, 500.0);
      expect(wallet.totalWithdraw, 249.5);
    });

    test('3 — throws SessionExpiredException on 401 when refresh fails',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'expired-token',
        'ludo_refresh_token': 'expired-refresh-token',
      });

      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Token expired.'},
            status: 401,
          )));

      await expectLater(
        () => walletService.getWallet(),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('4 — retries with refreshed token after 401', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'expired-access-token',
        'ludo_refresh_token': 'valid-refresh-token',
      });

      var walletCallCount = 0;
      buildServices(MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return _jsonResponse({
            'success': true,
            'data': {'access_token': 'new-access-token'},
          });
        }
        walletCallCount++;
        if (walletCallCount == 1) {
          return _jsonResponse(
            {'success': false, 'message': 'Access token expired.'},
            status: 401,
          );
        }
        return _walletResponse();
      }));

      final wallet = await walletService.getWallet();

      expect(wallet.id, 'wallet-uuid-1');
      expect(walletCallCount, 2);
      expect(await tokenStorage.getAccessToken(), 'new-access-token');
    });

    test('5 — throws ApiException on 500 server error', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Internal server error.'},
            status: 500,
          )));

      await expectLater(
        () => walletService.getWallet(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('6 — throws on malformed response (wallet key missing)', () async {
      buildServices(MockClient((_) async => _jsonResponse({
            'success': true,
            'data': {'unexpected': 'shape'},
          })));

      await expectLater(
        () => walletService.getWallet(),
        throwsA(anything),
      );
    });

    test('7 — throws Exception on network failure', () async {
      buildServices(
        MockClient((_) async => throw Exception('Network unreachable')),
      );

      await expectLater(
        () => walletService.getWallet(),
        throwsException,
      );
    });
  });

  // ─── WalletService.getHistory ─────────────────────────────────────────────

  group('WalletService.getHistory', () {
    test('8 — returns WalletHistory with empty transactions for new player',
        () async {
      buildServices(MockClient((_) async => _historyResponse()));

      final history = await walletService.getHistory();

      expect(history.transactions, isEmpty);
      expect(history.total, 0);
      expect(history.limit, 20);
      expect(history.offset, 0);
    });

    test('9 — returns populated WalletHistory with transaction fields', () async {
      buildServices(
          MockClient((_) async => _historyResponse(transactions: [_txJson])));

      final history = await walletService.getHistory();

      expect(history.transactions, hasLength(1));
      final tx = history.transactions.first;
      expect(tx.id, 'tx-uuid-1');
      expect(tx.type, 'reward');
      expect(tx.amount, 50.0);
      expect(tx.status, 'completed');
      expect(tx.reference, isNull);
      expect(tx.createdAt, '2026-07-18T12:00:00.000Z');
      expect(history.total, 1);
    });

    test('10 — multiple transactions are all parsed', () async {
      final txs = [
        _txJson,
        {
          'id': 'tx-uuid-2',
          'type': 'entry_fee',
          'amount': 10.0,
          'status': 'completed',
          'reference': 'MATCH-001',
          'created_at': '2026-07-18T11:00:00.000Z',
        },
      ];
      buildServices(
          MockClient((_) async => _historyResponse(transactions: txs)));

      final history = await walletService.getHistory();

      expect(history.transactions, hasLength(2));
      expect(history.transactions[1].type, 'entry_fee');
      expect(history.transactions[1].reference, 'MATCH-001');
      expect(history.total, 2);
    });

    test('11 — custom limit and offset are sent as query params', () async {
      http.Request? captured;
      buildServices(MockClient((req) async {
        if (req.url.path.contains('/wallet/history')) {
          captured = req;
          return _historyResponse(
              transactions: [_txJson], limit: 5, offset: 10);
        }
        return _jsonResponse({'success': false}, status: 500);
      }));

      final history = await walletService.getHistory(limit: 5, offset: 10);

      expect(captured, isNotNull);
      expect(captured!.url.queryParameters['limit'], '5');
      expect(captured!.url.queryParameters['offset'], '10');
      expect(history.limit, 5);
      expect(history.offset, 10);
    });

    test('12 — default limit=20 and offset=0 are sent when not specified',
        () async {
      http.Request? captured;
      buildServices(MockClient((req) async {
        if (req.url.path.contains('/wallet/history')) {
          captured = req;
          return _historyResponse();
        }
        return _jsonResponse({'success': false}, status: 500);
      }));

      await walletService.getHistory();

      expect(captured, isNotNull);
      expect(captured!.url.queryParameters['limit'], '20');
      expect(captured!.url.queryParameters['offset'], '0');
    });

    test('13 — throws SessionExpiredException on 401 when refresh fails',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'expired-token',
        'ludo_refresh_token': 'expired-refresh-token',
      });

      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Token expired.'},
            status: 401,
          )));

      await expectLater(
        () => walletService.getHistory(),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('14 — throws ApiException on 500 server error', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Internal server error.'},
            status: 500,
          )));

      await expectLater(
        () => walletService.getHistory(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('15 — throws on malformed response (transactions key missing)',
        () async {
      buildServices(MockClient((_) async => _jsonResponse({
            'success': true,
            'data': {'unexpected': 'shape'},
          })));

      await expectLater(
        () => walletService.getHistory(),
        throwsA(anything),
      );
    });

    test('16 — throws Exception on network failure', () async {
      buildServices(
        MockClient((_) async => throw Exception('Network unreachable')),
      );

      await expectLater(
        () => walletService.getHistory(),
        throwsException,
      );
    });
  });

  // ─── Wallet.fromJson ──────────────────────────────────────────────────────

  group('Wallet.fromJson', () {
    test('17 — parses all fields correctly', () async {
      buildServices(MockClient((_) async => _walletResponse()));

      final wallet = await walletService.getWallet();

      expect(wallet.id, 'wallet-uuid-1');
      expect(wallet.points, isA<double>());
      expect(wallet.totalDeposit, isA<double>());
      expect(wallet.totalWithdraw, isA<double>());
      expect(wallet.updatedAt, isNotEmpty);
    });

    test('18 — integer values from server are coerced to double', () async {
      // Backend sends points: 0 (int), not 0.0 (double)
      buildServices(MockClient((_) async => _walletResponse(
            overrides: {'points': 100, 'total_deposit': 200, 'total_withdraw': 100},
          )));

      final wallet = await walletService.getWallet();

      expect(wallet.points, 100.0);
      expect(wallet.totalDeposit, 200.0);
      expect(wallet.totalWithdraw, 100.0);
    });
  });

  // ─── WalletTransaction.fromJson ───────────────────────────────────────────

  group('WalletTransaction.fromJson', () {
    test('19 — reference is null when absent from response', () async {
      buildServices(
          MockClient((_) async => _historyResponse(transactions: [_txJson])));

      final history = await walletService.getHistory();
      final tx = history.transactions.first;

      expect(tx.reference, isNull);
    });

    test('20 — reference is populated when present', () async {
      final txWithRef = {..._txJson, 'reference': 'EXTERNAL-REF-42'};
      buildServices(MockClient(
          (_) async => _historyResponse(transactions: [txWithRef])));

      final history = await walletService.getHistory();
      final tx = history.transactions.first;

      expect(tx.reference, 'EXTERNAL-REF-42');
    });

    test('21 — integer amount from server is coerced to double', () async {
      final txIntAmount = {..._txJson, 'amount': 75};
      buildServices(MockClient(
          (_) async => _historyResponse(transactions: [txIntAmount])));

      final history = await walletService.getHistory();

      expect(history.transactions.first.amount, 75.0);
    });
  });
}
