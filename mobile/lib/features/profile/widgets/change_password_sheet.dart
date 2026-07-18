import 'package:flutter/material.dart';
import '../../../core/errors/api_exception.dart';
import '../services/change_password_service.dart';

// ─── Theme constants ──────────────────────────────────────────────────────────
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Bottom sheet that lets the player change their password.
///
/// Handles [WrongCurrentPasswordException] by highlighting the
/// current-password field, so the player never loses their session.
///
/// [onSuccess] is called when the backend confirms the change (before
/// the sheet is dismissed).  The caller may show a snack-bar or navigate
/// to a login screen since all refresh tokens are revoked on success.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({
    super.key,
    required this.changePasswordService,
    required this.onSuccess,
  });

  final ChangePasswordService changePasswordService;
  final VoidCallback onSuccess;

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  /// Populated when the backend rejects the current password; forces the
  /// validator on the current-password field to show an inline error.
  String? _wrongPasswordError;

  /// General server or network error shown in the banner below the form.
  String? _serverError;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear any previous wrong-password flag and re-validate.
    setState(() => _wrongPasswordError = null);

    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });

    try {
      await widget.changePasswordService.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (mounted) {
        widget.onSuccess();
        Navigator.of(context).pop();
      }
    } on WrongCurrentPasswordException {
      if (mounted) {
        setState(() {
          _wrongPasswordError = 'Current password is incorrect.';
          _saving = false;
        });
        // Trigger rebuild of the form so the validator picks up the new error.
        _formKey.currentState!.validate();
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

            // ── Title ──────────────────────────────────────────────────────
            const Text(
              'Change Password',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All other devices will be signed out after a successful change.',
              style: TextStyle(color: _kTextSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // ── Form ───────────────────────────────────────────────────────
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Current password
                  _PasswordField(
                    controller: _currentCtrl,
                    label: 'Current Password',
                    obscure: !_showCurrent,
                    onToggle: () =>
                        setState(() => _showCurrent = !_showCurrent),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Current password is required.';
                      }
                      if (_wrongPasswordError != null) {
                        return _wrongPasswordError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // New password
                  _PasswordField(
                    controller: _newCtrl,
                    label: 'New Password',
                    obscure: !_showNew,
                    onToggle: () => setState(() => _showNew = !_showNew),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'New password is required.';
                      }
                      if (v.length < 8) {
                        return 'Password must be at least 8 characters.';
                      }
                      if (!RegExp(r'[a-zA-Z]').hasMatch(v)) {
                        return 'Password must contain at least one letter.';
                      }
                      if (!RegExp(r'\d').hasMatch(v)) {
                        return 'Password must contain at least one digit.';
                      }
                      if (v == _currentCtrl.text) {
                        return 'New password must differ from current.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm new password (client-side only)
                  _PasswordField(
                    controller: _confirmCtrl,
                    label: 'Confirm New Password',
                    obscure: !_showConfirm,
                    onToggle: () =>
                        setState(() => _showConfirm = !_showConfirm),
                    validator: (v) {
                      if (v != _newCtrl.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            // ── Server error ───────────────────────────────────────────────
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
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: _kPrimary.withAlpha(128),
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
                    : const Text('Change Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Password form field ──────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kTextSecondary),
        prefixIcon: const Icon(Icons.lock_outline, color: _kPrimary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: _kTextSecondary,
            size: 20,
          ),
          onPressed: onToggle,
        ),
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
