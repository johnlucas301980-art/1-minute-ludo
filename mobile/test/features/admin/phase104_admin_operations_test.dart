import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/admin/models/admin_report.dart';
import 'package:one_minute_ludo/features/admin/models/admin_setting.dart';
import 'package:one_minute_ludo/features/admin/models/admin_wallet.dart';
import 'package:one_minute_ludo/features/admin/services/admin_service.dart';

http.Response _response(Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _walletJson() => {
      'wallet_id': 'wallet-1',
      'user_id': 'user-1',
      'player_id': 'LUD-000001',
      'full_name': 'Admin Test Player',
      'user_status': 'active',
      'points': '125.50',
      'total_deposit': '200',
      'total_withdraw': 25,
      'transaction_count': 2,
      'last_transaction_at': '2026-07-24T10:00:00.000Z',
      'updated_at': '2026-07-24T10:01:00.000Z',
    };

Map<String, dynamic> _reportJson() => {
      'from': '2026-06-24T00:00:00.000Z',
      'to': '2026-07-24T00:00:00.000Z',
      'users': {
        'total': 10,
        'new_users': '2',
        'active': 8,
        'suspended': 1,
        'banned': 1,
      },
      'matches': {
        'total': 20,
        'waiting': 1,
        'in_progress': 2,
        'finished': 16,
        'cancelled': 1,
      },
      'wallets': {
        'wallet_count': 10,
        'total_points': '1000',
        'total_deposit': 2000,
        'total_withdraw': '500.25',
      },
      'transactions': {
        'total': 30,
        'deposit': '2000',
        'withdraw': 500,
        'reward': '700.5',
        'entry_fee': 300,
        'refund': '25',
      },
      'support': {
        'open': 2,
        'in_progress': 1,
        'resolved': 5,
        'closed': 10,
      },
    };

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'admin-token',
    });
  });

  test('Phase 10.4 models parse numeric strings and nullable dates', () {
    final wallet = AdminWallet.fromJson(_walletJson());
    expect(wallet.points, 125.5);
    expect(wallet.totalWithdraw, 25);
    expect(wallet.transactionCount, 2);
    expect(wallet.lastTransactionAt, isNotNull);

    final transaction = AdminWalletTransaction.fromJson({
      'id': 'tx-1',
      'user_id': 'user-1',
      'player_id': 'LUD-000001',
      'full_name': 'Admin Test Player',
      'type': 'reward',
      'amount': '50.25',
      'status': 'completed',
      'reference': null,
      'created_at': '2026-07-24T11:00:00.000Z',
    });
    expect(transaction.amount, 50.25);
    expect(transaction.reference, isNull);
  });

  test('Phase 10.4 report and settings models parse all sections', () {
    final report = AdminReport.fromJson(_reportJson());
    expect(report.users.newUsers, 2);
    expect(report.matches.inProgress, 2);
    expect(report.wallets.totalDeposit, 2000);
    expect(report.transactions.reward, 700.5);
    expect(report.support.closed, 10);

    final setting = AdminSetting.fromJson({
      'id': 'setting-1',
      'key': 'match_duration_seconds',
      'value': '60',
      'updated_at': '2026-07-24T11:00:00.000Z',
    });
    expect(setting.key, 'match_duration_seconds');
    expect(setting.value, '60');
  });

  test('AdminService Phase 10.4 methods use the expected endpoints', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/admin/wallets')) {
        return _response({
          'success': true,
          'data': {
            'wallets': [_walletJson()],
            'pagination': {'total': 1},
          },
        });
      }
      if (request.url.path.contains('/transactions')) {
        return _response({
          'success': true,
          'data': {
            'transactions': [],
            'pagination': {'total': 0},
          },
        });
      }
      if (request.url.path.endsWith('/admin/reports')) {
        return _response({'success': true, 'data': {'report': _reportJson()}});
      }
      if (request.method == 'GET' && request.url.path.endsWith('/admin/settings')) {
        return _response({
          'success': true,
          'data': {
            'settings': [
              {
                'id': 'setting-1',
                'key': 'match_duration_seconds',
                'value': '60',
                'updated_at': '2026-07-24T11:00:00.000Z',
              },
            ],
          },
        });
      }
      return _response({
        'success': true,
        'data': {
          'setting': {
            'id': 'setting-1',
            'key': 'match_duration_seconds',
            'value': '90',
            'updated_at': '2026-07-24T11:00:00.000Z',
          },
        },
      });
    });
    final service = AdminService(
      apiClient: ApiClient(
        tokenStorage: const TokenStorage(),
        httpClient: client,
      ),
    );

    final wallets = await service.listWallets(search: 'LUD-000001');
    final transactions = await service.listWalletTransactions('user-1');
    final report = await service.getReport(from: '2026-06-24', to: '2026-07-24');
    final settings = await service.listSettings();
    final updated = await service.updateSetting('match_duration_seconds', '90');

    expect(wallets.wallets, hasLength(1));
    expect(transactions.transactions, isEmpty);
    expect(report.users.total, 10);
    expect(settings, hasLength(1));
    expect(updated.value, '90');
    expect(requests.map((request) => request.url.path), containsAll([
      '/api/admin/wallets',
      '/api/admin/wallets/user-1/transactions',
      '/api/admin/reports',
      '/api/admin/settings',
      '/api/admin/settings/match_duration_seconds',
    ]));
    expect(requests.first.url.queryParameters['search'], 'LUD-000001');
    expect(requests[2].url.queryParameters['from'], '2026-06-24');
    expect(requests[2].url.queryParameters['to'], '2026-07-24');
    expect(requests.last.method, 'PUT');
    expect(jsonDecode(requests.last.body)['value'], '90');
  });
}