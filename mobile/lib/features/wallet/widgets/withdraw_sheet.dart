import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/payment_result.dart';
import '../services/payment_service.dart';

// ─── Theme constants (consistent with WalletScreen) ───────────────────────────
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kRed = Color(0xFFFF4C4C);

/// Bottom sheet for withdrawing points from the authenticated player's wallet.
///
/// Displays [currentBalance] so the player knows their available points before
/// submitting.  Catches [InsufficientBalanceException] (HTTP 422) and shows it
/// as an inline error banner rather than closing the session — the player can
/// adjust the amount and retry.
///
/// All dependencies are injected through the constructor — no singletons.
class WithdrawSheet extends StatefulWidget {
  const WithdrawSheet({
    super.key,
    required this.paymentService,
    required this.currentBalance,
    required this.onSuccess,
  });

  final PaymentService paymentService;

  /// The wallet's current balance, shown in the sheet for context.
  /// Passed by the caller from the last-known [Wallet.points].
  final double currentBalance;

  final ValueChanged<PaymentResult> onSuccess;

  @override
  State<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<WithdrawSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();

  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final amount = double.parse(_amountCtrl.text.trim());
    final refText = _referenceCtrl.text.trim();
    final reference = refText.isEmpty ? null : refText;

    try {
      final result = await widget.paymentService.withdraw(
        amount: amount,
        reference: reference,
      );
      if (mounted) {
        widget.onSuccess(result);
        Navigator.of(context).pop();
      }
    } on InsufficientBalanceException {
      // HTTP 422 — domain rejection; session is intact; show inline banner.
      if (mounted) {
        setState(() {
          _serverError = 'Insufficient balance. Please enter a lower amount.';
          _saving = false;
        });
      }
    } on SessionExpiredException {
      if (mounted) {
        setState(() {
          _serverError = 'Session expired. Please log in again.';
          _saving = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _serverError = e.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverError = 'Something went wrong. Please try again.';
          _saving = false;
        });
      }
    }
  }

  String _formatBalance(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title row ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kRed.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: _kRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Withdraw Points',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Current balance chip ───────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: _kTextSecondary,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Available: ',
                    style: TextStyle(
                      color: _kTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${_formatBalance(widget.currentBalance)} pts',
                    key: const Key('current_balance_text'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Form ───────────────────────────────────────────────────────
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _AmountField(controller: _amountCtrl),
                  const SizedBox(height: 16),
                  _ReferenceField(controller: _referenceCtrl),
                ],
              ),
            ),

            // ── Server / domain error banner ───────────────────────────────
            if (_serverError != null) ...[
              const SizedBox(height: 14),
              _ErrorBanner(message: _serverError!),
            ],

            const SizedBox(height: 24),

            // ── Submit button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  disabledBackgroundColor: _kRed.withAlpha(128),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Withdraw'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Amount field ─────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Amount',
        hintText: 'e.g. 100 or 49.99',
        hintStyle: const TextStyle(color: _kTextSecondary, fontSize: 13),
        labelStyle: const TextStyle(color: _kTextSecondary),
        prefixIcon:
            const Icon(Icons.attach_money_rounded, color: _kPrimary, size: 20),
        filled: true,
        fillColor: const Color(0xFF0D0D1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4C4C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4C4C), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF4C4C)),
      ),
      validator: (v) {
        final s = v?.trim() ?? '';
        if (s.isEmpty) return 'Amount is required.';
        final value = double.tryParse(s);
        if (value == null) return 'Enter a valid number.';
        if (value <= 0) return 'Amount must be greater than zero.';
        if (value > 1000000) return 'Amount must not exceed 1,000,000.';
        return null;
      },
    );
  }
}

// ─── Reference field ──────────────────────────────────────────────────────────

class _ReferenceField extends StatelessWidget {
  const _ReferenceField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Reference (optional)',
        hintText: 'e.g. payout reference ID',
        hintStyle: const TextStyle(color: _kTextSecondary, fontSize: 13),
        labelStyle: const TextStyle(color: _kTextSecondary),
        prefixIcon: const Icon(Icons.tag_rounded, color: _kPrimary, size: 20),
        filled: true,
        fillColor: const Color(0xFF0D0D1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4C4C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4C4C), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF4C4C)),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 76, 76, 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromRGBO(255, 76, 76, 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF4C4C), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFF4C4C), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
