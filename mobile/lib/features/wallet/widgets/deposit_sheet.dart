import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/payment_result.dart';
import '../services/payment_service.dart';

// ─── Theme constants (consistent with WalletScreen) ───────────────────────────
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kGreen = Color(0xFF4CAF50);

/// Bottom sheet for depositing points into the authenticated player's wallet.
///
/// Validates the amount client-side before calling [PaymentService.deposit].
/// Calls [onSuccess] with the server-confirmed [PaymentResult] before
/// dismissing — the caller should use this to refresh the wallet display.
///
/// All dependencies are injected through the constructor — no singletons.
class DepositSheet extends StatefulWidget {
  const DepositSheet({
    super.key,
    required this.paymentService,
    required this.onSuccess,
  });

  final PaymentService paymentService;
  final ValueChanged<PaymentResult> onSuccess;

  @override
  State<DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<DepositSheet> {
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
      final result = await widget.paymentService.deposit(
        amount: amount,
        reference: reference,
      );
      if (mounted) {
        widget.onSuccess(result);
        Navigator.of(context).pop();
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
                    color: _kGreen.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_downward_rounded,
                    color: _kGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Deposit Points',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Verify your payment is complete before submitting.',
              style: TextStyle(color: _kTextSecondary, fontSize: 12),
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

            // ── Server error banner ────────────────────────────────────────
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
                  backgroundColor: _kGreen,
                  disabledBackgroundColor: _kGreen.withAlpha(128),
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
                    : const Text('Deposit'),
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
        hintText: 'e.g. gateway transaction ID',
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
