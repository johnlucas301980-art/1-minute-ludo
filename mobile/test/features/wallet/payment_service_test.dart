import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/wallet/services/payment_service.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Canonical wallet JSON as returned inside deposit/withdraw responses.
final _walletJson = {
  'id': 'wallet-uuid-1',
  'points': 750.0,
  'total_deposit': 1000.0,
  'total_withdraw': 250.0,
  'updated_at': '2026-07-18T12:00:00.000Z',
};

/// Canonical deposit transaction JSON.
final _depositTxJson = {
  'id': 'tx-deposit-1',
  'type': 'deposit',
  'amount': 500.0,
  'status': 'completed',
  'reference': null,
  'created_at': '2026-07-18T12:00:00.000Z',
};

/// Canonical withdraw transaction JSON.
final _withdrawTxJson = {
  'id': 'tx-withdraw-1',
  'type': 'withdraw',
  'amount': 200.0,
  'status': 'completed',
  'reference': null,
  'created_at': '2026-07-18T12:05:00.000Z',
};

/// A successful deposit response.
http.Response _depositResponse({
  Map<String, dynamic>? walletOverrides,
  Map<String, dynamic>? txOverrides,
}) {
  final wallet = {..._walletJson, ...?walletOverrides};
  final tx = {..._depositTxJson, ...?txOverrides};
  return _jsonResponse({
    'success': true,
    'data': {'wallet': wallet, 'transaction': tx},
  });
}

/// A successful withdraw response.
http.Response _withdrawResponse({
  Map<String, dynamic>? walletOverrides,
  Map<String, dynamic>? txOverrides,
}) {
  final wallet = {..._walletJson, ...?walletOverrides};
  final tx = {..._withdrawTxJson, ...?txOverrides};
  return _jsonResponse({
    'success': true,
    'data': {'wallet': wallet, 'transaction': tx},
  });
}

/// A 422 insufficient-balance response.
http.Response _insufficientBalanceResponse() => _jsonResponse(
      {'success': false, 'message': 'Insufficient balance.'},
      status: 422,
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late PaymentService paymentService;

  void buildServices(http.Client mockHttpClient) {
    tokenStorage = const TokenStorage();
    apiClient = ApiClient(tokenStorage: tokenStorage, httpClient: mockHttpClient);
    paymentService = PaymentService(apiClient: apiClient);
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'valid-access-token',
    });
  });

  // ─── PaymentService.deposit ───────────────────────────────────────────────

  group('PaymentService.deposit — happy path', () {
    test('1 — returns PaymentResult with correct wallet fields', () async {
      buildServices(MockClient((_) async => _depositResponse()));

      final result = await paymentService.deposit(amount: 500);

      expect(result.wallet.id, 'wallet-uuid-1');
      expect(result.wallet.points, 750.0);
      expect(result.wallet.totalDeposit, 1000.0);
      expect(result.wallet.totalWithdraw, 250.0);
      expect(result.wallet.updatedAt, '2026-07-18T12:00:00.000Z');
    });

    test('2 — returns PaymentResult with correct transaction fields', () async {
      buildServices(MockClient((_) async => _depositResponse()));

      final result = await paymentService.deposit(amount: 500);

      expect(result.transaction.id, 'tx-deposit-1');
      expect(result.transaction.type, 'deposit');
      expect(result.transaction.amount, 500.0);
      expect(result.transaction.status, 'completed');
      expect(result.transaction.reference, isNull);
    });

    test('3 — sends amount in request body', () async {
      Map<String, dynamic>? capturedBody;

      buildServices(MockClient((req) async {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return _depositResponse();
      }));

      await paymentService.deposit(amount: 250.5);

      expect(capturedBody, isNotNull);
      expect(capturedBody!['amount'], 250.5);
    });

    test('4 — sends reference when provided', () async {
      Map<String, dynamic>? capturedBody;

      buildServices(MockClient((req) async {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return _depositResponse(txOverrides: {'reference': 'GATEWAY-TX-001'});
      }));

      await paymentService.deposit(amount: 100, reference: 'GATEWAY-TX-001');

      expect(capturedBody!['reference'], 'GATEWAY-TX-001');
    });

    test('5 — does not send reference key when omitted', () async {
      Map<String, dynamic>? capturedBody;

      buildServices(MockClient((req) async {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return _depositResponse();
      }));

      await paymentService.deposit(amount: 100);

      expect(capturedBody!.containsKey('reference'), isFalse);
    });

    test('6 — retries with refreshed token after 401', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'expired-access-token',
        'ludo_refresh_token': 'valid-refresh-token',
      });

      var depositCallCount = 0;

      buildServices(MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return _jsonResponse({
            'success': true,
            'data': {'access_token': 'new-access-token'},
          });
        }
        depositCallCount++;
        if (depositCallCount == 1) {
          return _jsonResponse(
            {'success': false, 'message': 'Access token expired.'},
            status: 401,
          );
        }
        return _depositResponse();
      }));

      final result = await paymentService.deposit(amount: 500);

      expect(result.wallet.id, 'wallet-uuid-1');
      expect(depositCallCount, 2);
      expect(await tokenStorage.getAccessToken(), 'new-access-token');
    });

    test('7 — throws SessionExpiredException on 401 when refresh fails',
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
        () => paymentService.deposit(amount: 500),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('8 — throws ApiException on 500 server error', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Internal server error.'},
            status: 500,
          )));

      await expectLater(
        () => paymentService.deposit(amount: 500),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('9 — throws Exception on network failure', () async {
      buildServices(
        MockClient((_) async => throw Exception('Network unreachable')),
      );

      await expectLater(
        () => paymentService.deposit(amount: 500),
        throwsException,
      );
    });

    test('10 — no access token stored → throws SessionExpiredException',
        () async {
      FlutterSecureStorage.setMockInitialValues({});

      buildServices(MockClient((_) async => _depositResponse()));

      await expectLater(
        () => paymentService.deposit(amount: 500),
        throwsA(isA<SessionExpiredException>()),
      );
    });
  });

  // ─── PaymentService.withdraw ──────────────────────────────────────────────

  group('PaymentService.withdraw — happy path', () {
    test('11 — returns PaymentResult with correct wallet and transaction fields',
        () async {
      buildServices(MockClient((_) async => _withdrawResponse()));

      final result = await paymentService.withdraw(amount: 200);

      expect(result.wallet.points, 750.0);
      expect(result.wallet.totalWithdraw, 250.0);
      expect(result.transaction.id, 'tx-withdraw-1');
      expect(result.transaction.type, 'withdraw');
      expect(result.transaction.amount, 200.0);
      expect(result.transaction.status, 'completed');
    });

    test('12 — sends amount and reference in request body', () async {
      Map<String, dynamic>? capturedBody;

      buildServices(MockClient((req) async {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return _withdrawResponse(txOverrides: {'reference': 'PAYOUT-001'});
      }));

      await paymentService.withdraw(amount: 200, reference: 'PAYOUT-001');

      expect(capturedBody!['amount'], 200.0);
      expect(capturedBody!['reference'], 'PAYOUT-001');
    });

    test('13 — does not send reference key when omitted', () async {
      Map<String, dynamic>? capturedBody;

      buildServices(MockClient((req) async {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return _withdrawResponse();
      }));

      await paymentService.withdraw(amount: 200);

      expect(capturedBody!.containsKey('reference'), isFalse);
    });
  });

  group('PaymentService.withdraw — insufficient balance', () {
    test('14 — server returns 422 → throws InsufficientBalanceException',
        () async {
      buildServices(
          MockClient((_) async => _insufficientBalanceResponse()));

      await expectLater(
        () => paymentService.withdraw(amount: 9999),
        throwsA(isA<InsufficientBalanceException>()),
      );
    });

    test(
        '15 — InsufficientBalanceException is an ApiException subclass '
        'with statusCode 422', () async {
      buildServices(
          MockClient((_) async => _insufficientBalanceResponse()));

      await expectLater(
        () => paymentService.withdraw(amount: 9999),
        throwsA(
          isA<InsufficientBalanceException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e, 'is ApiException', isA<ApiException>()),
        ),
      );
    });

    test('16 — InsufficientBalanceException carries the server message',
        () async {
      buildServices(
          MockClient((_) async => _insufficientBalanceResponse()));

      await expectLater(
        () => paymentService.withdraw(amount: 9999),
        throwsA(
          isA<InsufficientBalanceException>()
              .having((e) => e.message, 'message', 'Insufficient balance.'),
        ),
      );
    });
  });

  group('PaymentService.withdraw — session and network errors', () {
    test('17 — retries with refreshed token after 401', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'expired-access-token',
        'ludo_refresh_token': 'valid-refresh-token',
      });

      var withdrawCallCount = 0;

      buildServices(MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return _jsonResponse({
            'success': true,
            'data': {'access_token': 'new-access-token'},
          });
        }
        withdrawCallCount++;
        if (withdrawCallCount == 1) {
          return _jsonResponse(
            {'success': false, 'message': 'Access token expired.'},
            status: 401,
          );
        }
        return _withdrawResponse();
      }));

      final result = await paymentService.withdraw(amount: 200);

      expect(result.transaction.type, 'withdraw');
      expect(withdrawCallCount, 2);
      expect(await tokenStorage.getAccessToken(), 'new-access-token');
    });

    test('18 — throws SessionExpiredException on 401 when refresh fails',
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
        () => paymentService.withdraw(amount: 200),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('19 — throws ApiException on 500 server error', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Internal server error.'},
            status: 500,
          )));

      await expectLater(
        () => paymentService.withdraw(amount: 200),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('20 — throws Exception on network failure', () async {
      buildServices(
        MockClient((_) async => throw Exception('Network unreachable')),
      );

      await expectLater(
        () => paymentService.withdraw(amount: 200),
        throwsException,
      );
    });
  });

  // ─── PaymentResult.fromJson ───────────────────────────────────────────────

  group('PaymentResult.fromJson', () {
    test('21 — parses all wallet and transaction fields correctly', () async {
      buildServices(MockClient((_) async => _depositResponse()));

      final result = await paymentService.deposit(amount: 500);

      expect(result.wallet.id, isA<String>());
      expect(result.wallet.points, isA<double>());
      expect(result.wallet.totalDeposit, isA<double>());
      expect(result.wallet.totalWithdraw, isA<double>());
      expect(result.wallet.updatedAt, isNotEmpty);
      expect(result.transaction.id, isA<String>());
      expect(result.transaction.amount, isA<double>());
    });

    test('22 — integer amounts from server are coerced to double', () async {
      buildServices(MockClient((_) async => _depositResponse(
            walletOverrides: {'points': 750, 'total_deposit': 1000, 'total_withdraw': 250},
            txOverrides: {'amount': 500},
          )));

      final result = await paymentService.deposit(amount: 500);

      expect(result.wallet.points, 750.0);
      expect(result.wallet.totalDeposit, 1000.0);
      expect(result.wallet.totalWithdraw, 250.0);
      expect(result.transaction.amount, 500.0);
    });
  });
}
