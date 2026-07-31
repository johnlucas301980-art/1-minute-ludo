import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/country.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/country_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/country_picker_field.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kError         = Color(0xFFFF4C4C);

/// Login screen for the 1 Minute Ludo app.
///
/// - Auto-detects the user's country at mount time.
/// - Blocks login if the selected country has login disabled.
/// - Shows per-field server errors inline (red border + text below field).
/// - Uses Snackbar ONLY for network / server errors, never for validation.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.countryService,
    required this.onLoginSuccess,
    required this.onRegisterPressed,
  });

  final AuthService    authService;
  final CountryService countryService;
  final void Function(UserProfile profile) onLoginSuccess;
  final VoidCallback   onRegisterPressed;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey              = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController   = TextEditingController();

  final _identifierKey = GlobalKey<FormFieldState<String>>();
  final _passwordKey   = GlobalKey<FormFieldState<String>>();

  Map<String, String> _serverErrors = {};

  List<Country> _countries         = [];
  Country?      _selectedCountry;
  bool          _countriesLoading  = true;

  String?  _blockedMessage;
  String?  _generalError;  // non-field server errors shown as inline banner

  bool _submitting      = false;
  bool _obscurePassword = true;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Country loading ─────────────────────────────────────────────────────────

  Future<void> _loadCountries() async {
    final all      = await widget.countryService.getAll();
    final detected = await widget.countryService.getDetected();
    if (!mounted) return;
    setState(() {
      _countries        = all;
      _selectedCountry  = detected;
      _countriesLoading = false;
    });
    _checkCountryBlocked(_selectedCountry);
  }

  void _onCountryChanged(Country country) {
    setState(() {
      _selectedCountry = country;
      _blockedMessage  = null;
      _generalError    = null;
    });
    _checkCountryBlocked(country);
  }

  void _checkCountryBlocked(Country? country) {
    if (country == null) return;
    if (!country.isAllowed || !country.allowLogin) {
      setState(() => _blockedMessage =
          'This game is currently unavailable in your country due to local regulations.');
    } else {
      setState(() => _blockedMessage = null);
    }
  }

  // ─── Field error helpers ─────────────────────────────────────────────────────

  void _clearServerError(String field, GlobalKey<FormFieldState<String>> key) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors.remove(field));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) key.currentState?.validate();
      });
    }
    // Also clear the general error when user starts typing.
    if (_generalError != null) {
      setState(() => _generalError = null);
    }
  }

  // ─── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _serverErrors  = {};
      _blockedMessage = null;
      _generalError   = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    if (_blockedMessage != null) return;
    if (_selectedCountry != null &&
        (!_selectedCountry!.isAllowed || !_selectedCountry!.allowLogin)) {
      setState(() => _blockedMessage =
          'This game is currently unavailable in your country due to local regulations.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final profile = await widget.authService.login(
        identifier:  _identifierController.text.trim(),
        password:    _passwordController.text,
        countryIso2: _selectedCountry?.iso2,
      );
      if (mounted) widget.onLoginSuccess(profile);
    } on CountryBlockedException catch (e) {
      if (!mounted) return;
      setState(() {
        _blockedMessage = e.message;
        _submitting     = false;
      });
    } on FieldValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = Map.of(e.fieldErrors);
        _submitting   = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
    } on AccountForbiddenException catch (e) {
      // Suspended / banned — show inline (it's a specific account message).
      if (!mounted) return;
      setState(() {
        _generalError = e.message;
        _submitting   = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        // Invalid credentials — show as general error, not snackbar.
        setState(() {
          _generalError = e.message;
          _submitting   = false;
        });
      } else {
        setState(() => _submitting = false);
        _showSnackbar(e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackbar('Unable to reach the server. Please check your connection and try again.');
    }
  }

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

  // ─── Branding ────────────────────────────────────────────────────────────────

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
        autovalidateMode: AutovalidateMode.onUserInteraction,
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

            // ── Country picker ──────────────────────────────────────────────
            _countriesLoading
                ? const _CountryLoadingPlaceholder()
                : CountryPickerField(
                    key: const Key('country_field'),
                    countries: _countries,
                    selected: _selectedCountry,
                    onChanged: _onCountryChanged,
                    enabled: !_submitting,
                  ),
            const SizedBox(height: 16),

            // ── Country blocked banner ──────────────────────────────────────
            if (_blockedMessage != null) ...[
              _BlockedBanner(message: _blockedMessage!),
              const SizedBox(height: 16),
            ],

            // ── Identifier ──────────────────────────────────────────────────
            AuthTextField(
              key: const Key('identifier_field'),
              formFieldKey: _identifierKey,
              label: 'Email or Mobile Number',
              controller: _identifierController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              serverError: _serverErrors['identifier'],
              onChanged: (_) => _clearServerError('identifier', _identifierKey),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email or mobile number is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Password ────────────────────────────────────────────────────
            AuthTextField(
              key: const Key('password_field'),
              formFieldKey: _passwordKey,
              label: 'Password',
              controller: _passwordController,
              obscureText: _obscurePassword,
              onToggleObscure: _togglePasswordVisibility,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              serverError: _serverErrors['password'],
              onChanged: (_) => _clearServerError('password', _passwordKey),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── General error banner (invalid credentials, account suspended) ──
            if (_generalError != null) ...[
              _ErrorBanner(message: _generalError!),
              const SizedBox(height: 16),
            ],

            // ── Submit button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('login_button'),
                onPressed:
                    (_submitting || _blockedMessage != null) ? null : _submit,
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

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _CountryLoadingPlaceholder extends StatelessWidget {
  const _CountryLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF6C63FF),
          ),
        ),
      ),
    );
  }
}

class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 76, 76, 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromRGBO(255, 76, 76, 0.40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block_rounded, color: Color(0xFFFF4C4C), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFF4C4C),
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
        border: Border.all(color: const Color.fromRGBO(255, 76, 76, 0.40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4C4C), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFF4C4C),
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
