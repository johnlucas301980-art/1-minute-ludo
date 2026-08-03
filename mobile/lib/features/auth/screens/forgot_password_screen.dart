import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../services/password_reset_service.dart';
import '../widgets/auth_text_field.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kError         = Color(0xFFFF4C4C);
const _kSuccess       = Color(0xFF4CAF50);

// ─── Timer constant ───────────────────────────────────────────────────────────
const _kResendCooldownSeconds = 60;

/// Three-step password-reset screen.
///
/// Step 1 — Email: user enters email and taps "Send OTP".
/// Step 2 — OTP:   user enters the 6-digit OTP with a 60-second resend timer.
/// Step 3 — Password: user enters and confirms the new password.
///
/// Navigation callbacks:
/// - [onResetSuccess] is called after the password is successfully reset.
/// - [onBackToLogin] is called when the user taps the back-to-login link.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.passwordResetService,
    required this.onResetSuccess,
    required this.onBackToLogin,
  });

  final PasswordResetService passwordResetService;
  final VoidCallback         onResetSuccess;
  final VoidCallback         onBackToLogin;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // ─── Step tracking ────────────────────────────────────────────────────────
  _ResetStep _step = _ResetStep.email;

  // ─── Step 1 ───────────────────────────────────────────────────────────────
  final _emailFormKey  = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  String? _emailError;

  // ─── Step 2 ───────────────────────────────────────────────────────────────
  final _otpFormKey = GlobalKey<FormState>();
  final _otpCtrl    = TextEditingController();
  String? _otpError;

  // Resend-OTP countdown state
  Timer? _resendTimer;
  int    _resendSeconds = 0; // 0 means "button enabled"

  // ─── Step 3 ───────────────────────────────────────────────────────────────
  final _pwFormKey        = GlobalKey<FormState>();
  final _newPwCtrl        = TextEditingController();
  final _confirmPwCtrl    = TextEditingController();
  bool  _obscureNew       = true;
  bool  _obscureConfirm   = true;
  String? _pwError;

  // ─── Shared ───────────────────────────────────────────────────────────────
  bool    _submitting = false;
  String? _resetToken; // received from step 2

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ─── Resend-OTP timer ─────────────────────────────────────────────────────

  /// Starts (or restarts) the 60-second countdown that disables "Resend OTP".
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = _kResendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) {
          _resendSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  // ─── Step 1: send OTP ─────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    setState(() => _emailError = null);
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      await widget.passwordResetService.requestOtp(
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _step       = _ResetStep.otp;
      });
      _startResendTimer();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _emailError = e.message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emailFormKey.currentState?.validate();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackbar('Unable to reach the server. Please check your connection and try again.');
    }
  }

  // ─── Step 2: verify OTP ───────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    setState(() => _otpError = null);
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final token = await widget.passwordResetService.verifyOtp(
        email: _emailCtrl.text.trim(),
        otp:   _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting  = false;
        _resetToken  = token;
        _step        = _ResetStep.password;
      });
      _resendTimer?.cancel();
    } on OtpExpiredException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _otpError   = e.message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFormKey.currentState?.validate();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _otpError   = e.message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFormKey.currentState?.validate();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackbar('Unable to reach the server. Please check your connection and try again.');
    }
  }

  /// Called when the user taps "Resend OTP" (only active when countdown = 0).
  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 || _submitting) return;

    setState(() {
      _otpError   = null;
      _submitting = true;
    });
    try {
      await widget.passwordResetService.requestOtp(
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      _startResendTimer();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _otpError   = e.message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFormKey.currentState?.validate();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackbar('Unable to reach the server. Please check your connection and try again.');
    }
  }

  // ─── Step 3: confirm new password ─────────────────────────────────────────

  Future<void> _confirmReset() async {
    setState(() => _pwError = null);
    if (!(_pwFormKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      await widget.passwordResetService.confirmReset(
        resetToken:  _resetToken!,
        newPassword: _newPwCtrl.text,
      );
      if (!mounted) return;
      widget.onResetSuccess();
    } on OtpExpiredException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pwError    = e.message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pwFormKey.currentState?.validate();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pwError    = e.message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pwFormKey.currentState?.validate();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackbar('Unable to reach the server. Please check your connection and try again.');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _kError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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
              _buildStepCard(),
              const SizedBox(height: 24),
              _buildBackToLogin(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Branding ─────────────────────────────────────────────────────────────

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 215, 0, 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color.fromRGBO(255, 215, 0, 0.30)),
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

  // ─── Step card ────────────────────────────────────────────────────────────

  Widget _buildStepCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: switch (_step) {
        _ResetStep.email    => _buildEmailStep(),
        _ResetStep.otp      => _buildOtpStep(),
        _ResetStep.password => _buildPasswordStep(),
      },
    );
  }

  // ─── Step 1: email ────────────────────────────────────────────────────────

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forgot Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your email address and we\'ll send you a one-time code.',
            style: TextStyle(color: _kTextSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),

          AuthTextField(
            key: const Key('forgot_email_field'),
            label: 'Email Address',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
            serverError: _emailError,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
            onFieldSubmitted: (_) => _sendOtp(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email address is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('send_otp_button'),
              onPressed: _submitting ? null : _sendOtp,
              style: _primaryButtonStyle(),
              child: _submitting
                  ? _loadingIndicator()
                  : const Text('Send OTP'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: OTP ──────────────────────────────────────────────────────────

  Widget _buildOtpStep() {
    final canResend = _resendSeconds == 0 && !_submitting;

    return Form(
      key: _otpFormKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter OTP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'A 6-digit code was sent to '),
                TextSpan(
                  text: _emailCtrl.text.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          AuthTextField(
            key: const Key('otp_field'),
            label: 'One-Time Code',
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
            serverError: _otpError,
            onChanged: (_) {
              if (_otpError != null) setState(() => _otpError = null);
            },
            onFieldSubmitted: (_) => _verifyOtp(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the code sent to your email.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Resend OTP button with countdown ─────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('resend_otp_button'),
              onPressed: canResend ? _resendOtp : null,
              style: TextButton.styleFrom(
                foregroundColor: _kPrimary,
                disabledForegroundColor: _kTextSecondary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _resendSeconds > 0
                    ? 'Resend OTP (${_resendSeconds}s)'
                    : 'Resend OTP',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('verify_otp_button'),
              onPressed: _submitting ? null : _verifyOtp,
              style: _primaryButtonStyle(),
              child: _submitting
                  ? _loadingIndicator()
                  : const Text('Verify OTP'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 3: new password ─────────────────────────────────────────────────

  Widget _buildPasswordStep() {
    return Form(
      key: _pwFormKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a strong password with uppercase, lowercase, and a number.',
            style: TextStyle(color: _kTextSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),

          AuthTextField(
            key: const Key('new_password_field'),
            label: 'New Password',
            controller: _newPwCtrl,
            obscureText: _obscureNew,
            onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
            serverError: _pwError,
            onChanged: (_) {
              if (_pwError != null) setState(() => _pwError = null);
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'New password is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          AuthTextField(
            key: const Key('confirm_password_field'),
            label: 'Confirm Password',
            controller: _confirmPwCtrl,
            obscureText: _obscureConfirm,
            onToggleObscure: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
            onChanged: (_) {
              if (_pwError != null) setState(() => _pwError = null);
            },
            onFieldSubmitted: (_) => _confirmReset(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your new password.';
              }
              if (value != _newPwCtrl.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('reset_password_button'),
              onPressed: _submitting ? null : _confirmReset,
              style: _primaryButtonStyle(),
              child: _submitting
                  ? _loadingIndicator()
                  : const Text('Reset Password'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Back to login link ───────────────────────────────────────────────────

  Widget _buildBackToLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Remember your password?',
          style: TextStyle(color: _kTextSecondary, fontSize: 14),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          key: const Key('back_to_login_link'),
          onTap: _submitting ? null : widget.onBackToLogin,
          child: const Text(
            'Log In',
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

  // ─── Shared style helpers ─────────────────────────────────────────────────

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color.fromRGBO(108, 99, 255, 0.55),
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _loadingIndicator() {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

// ─── Step enum ────────────────────────────────────────────────────────────────

enum _ResetStep { email, otp, password }
