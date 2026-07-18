import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold = Color(0xFFFFD700);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kError = Color(0xFFFF4C4C);

/// Displays the login form for the 1 Minute Ludo app.
///
/// Navigation is the parent's responsibility — this screen never calls
/// [Navigator] directly.  The parent supplies two callbacks:
///
/// - [onLoginSuccess] — called with the [UserProfile] after a successful login.
/// - [onRegisterPressed] — called when the user taps the "Register" link.
///
/// All dependencies are injected through the constructor — no singletons.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.onLoginSuccess,
    required this.onRegisterPressed,
  });

  final AuthService authService;

  /// Called with the authenticated [UserProfile] after a successful login.
  final void Function(UserProfile profile) onLoginSuccess;

  /// Called when the user taps the "Register" link.
  final VoidCallback onRegisterPressed;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Clear any previous server error before re-validating.
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final profile = await widget.authService.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) widget.onLoginSuccess(profile);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not connect to the server. Please try again.';
          _submitting = false;
        });
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildBranding(),
              const SizedBox(height: 40),
              _buildFormCard(),
              const SizedBox(height: 24),
              _buildRegisterLink(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Branding section ────────────────────────────────────────────────────────

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 215, 0, 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color.fromRGBO(255, 215, 0, 0.30),
            ),
          ),
          child: const Icon(
            Icons.sports_esports_rounded,
            color: _kGold,
            size: 38,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '1 Minute Ludo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'PLAY  ·  WIN  ·  REPEAT',
          style: TextStyle(
            color: _kTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }

  // ─── Form card ───────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log In',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 20),

            // ── Identifier ────────────────────────────────────────────────────
            AuthTextField(
              key: const Key('identifier_field'),
              label: 'Email or Mobile Number',
              controller: _identifierController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email or mobile number.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Password ──────────────────────────────────────────────────────
            AuthTextField(
              key: const Key('password_field'),
              label: 'Password',
              controller: _passwordController,
              obscureText: _obscurePassword,
              onToggleObscure: _togglePasswordVisibility,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Error banner ──────────────────────────────────────────────────
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],

            // ── Submit button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('login_button'),
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color.fromRGBO(108, 99, 255, 0.55),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Log In'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Register link ────────────────────────────────────────────────────────────

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account?",
          style: TextStyle(color: _kTextSecondary, fontSize: 14),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          key: const Key('register_link'),
          onTap: _submitting ? null : widget.onRegisterPressed,
          child: const Text(
            'Register',
            style: TextStyle(
              color: _kPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 76, 76, 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color.fromRGBO(255, 76, 76, 0.40),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _kError,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _kError,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
