import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kError = Color(0xFFFF4C4C);

/// Displays the registration form for the 1 Minute Ludo app.
///
/// Navigation is the parent's responsibility — this screen never calls
/// [Navigator] directly.  The parent supplies two callbacks:
///
/// - [onRegisterSuccess] — called with the new [UserProfile] after a successful
///   registration.
/// - [onLoginPressed] — called when the user taps the "Log in" link or the
///   AppBar back button.
///
/// All dependencies are injected through the constructor — no singletons.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.authService,
    required this.onRegisterSuccess,
    required this.onLoginPressed,
  });

  final AuthService authService;

  /// Called with the new [UserProfile] after a successful registration.
  final void Function(UserProfile profile) onRegisterSuccess;

  /// Called when the user taps the "Log in" link or the AppBar back button.
  final VoidCallback onLoginPressed;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() => _submitting = true);

    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();

    try {
      final profile = await widget.authService.register(
        fullName: _fullNameController.text.trim(),
        password: _passwordController.text,
        email: email.isEmpty ? null : email,
        mobile: mobile.isEmpty ? null : mobile,
      );
      if (mounted) widget.onRegisterSuccess(profile);
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
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: _kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _submitting ? null : widget.onLoginPressed,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: _buildForm(),
        ),
      ),
    );
  }

  // ─── Form ────────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Full Name ─────────────────────────────────────────────────────
          AuthTextField(
            key: const Key('full_name_field'),
            label: 'Full Name',
            controller: _fullNameController,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Email (optional) ──────────────────────────────────────────────
          AuthTextField(
            key: const Key('email_field'),
            label: 'Email (optional)',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 16),

          // ── Mobile (optional) ─────────────────────────────────────────────
          AuthTextField(
            key: const Key('mobile_field'),
            label: 'Mobile Number (optional)',
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
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
                return 'Please enter a password.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // ── Error banner ──────────────────────────────────────────────────
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],

          // ── Submit button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('register_button'),
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
                  : const Text('Register'),
            ),
          ),
          const SizedBox(height: 24),

          // ── Login link ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(color: _kTextSecondary, fontSize: 14),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                key: const Key('login_link'),
                onTap: _submitting ? null : widget.onLoginPressed,
                child: const Text(
                  'Log in',
                  style: TextStyle(
                    color: _kPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
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
