import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kError         = Color(0xFFFF4C4C);

/// Registration screen for the 1 Minute Ludo app.
///
/// - Auto-detects the user's country at mount time.
/// - Validates phone number against the selected country's dial code.
/// - Shows per-field server errors inline (red border + text below field).
/// - Uses Snackbar ONLY for network / server errors, never for validation.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.authService,
    required this.countryService,
    required this.onRegisterSuccess,
    required this.onLoginPressed,
  });

  final AuthService     authService;
  final CountryService  countryService;
  final void Function(UserProfile profile) onRegisterSuccess;
  final VoidCallback    onLoginPressed;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey               = GlobalKey<FormState>();
  final _fullNameController    = TextEditingController();
  final _emailController       = TextEditingController();
  final _mobileController      = TextEditingController();
  final _passwordController    = TextEditingController();
  final _referralCodeController = TextEditingController();

  // Per-field GlobalKeys so we can re-validate individual fields when
  // a server error is cleared (without triggering errors on other fields).
  final _fullNameKey    = GlobalKey<FormFieldState<String>>();
  final _emailKey       = GlobalKey<FormFieldState<String>>();
  final _mobileKey      = GlobalKey<FormFieldState<String>>();
  final _passwordKey    = GlobalKey<FormFieldState<String>>();
  final _referralCodeKey = GlobalKey<FormFieldState<String>>();

  // Server-side field errors returned by the backend.
  Map<String, String> _serverErrors = {};

  // Country state.
  List<Country> _countries    = [];
  Country?      _selectedCountry;
  bool          _countriesLoading = true;

  // Blocked-country banner (shown inline, not as Snackbar).
  String? _blockedMessage;

  bool _submitting      = false;
  bool _googleSigningIn = false;
  bool _obscurePassword = true;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  // ─── Country loading ─────────────────────────────────────────────────────────

  Future<void> _loadCountries() async {
    final all      = await widget.countryService.getAll();
    final detected = await widget.countryService.getDetected();
    if (!mounted) return;
    setState(() {
      _countries         = all;
      _selectedCountry   = detected;
      _countriesLoading  = false;
    });
    _checkCountryBlocked(_selectedCountry);
  }

  void _onCountryChanged(Country country) {
    setState(() {
      _selectedCountry = country;
      _blockedMessage  = null;
      _serverErrors.remove('mobile');
    });
    _checkCountryBlocked(country);
  }

  void _checkCountryBlocked(Country? country) {
    if (country == null) return;
    if (!country.isAllowed || !country.allowRegistration) {
      setState(() {
        _blockedMessage =
            'This game is currently unavailable in your country due to local regulations.';
      });
    } else {
      setState(() => _blockedMessage = null);
    }
  }

  // ─── Field error helpers ─────────────────────────────────────────────────────

  /// Clears a server error for [field] and re-validates that field only.
  void _clearServerError(String field, GlobalKey<FormFieldState<String>> key) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors.remove(field));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) key.currentState?.validate();
      });
    }
  }

  // ─── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Clear previous server errors and re-run client validation.
    setState(() {
      _serverErrors.clear();
      _blockedMessage = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    // Block if country is restricted.
    if (_blockedMessage != null) return;
    if (_selectedCountry != null &&
        (!_selectedCountry!.isAllowed || !_selectedCountry!.allowRegistration)) {
      setState(() => _blockedMessage =
          'This game is currently unavailable in your country due to local regulations.');
      return;
    }

    setState(() => _submitting = true);

    final email  = _emailController.text.trim();
    final mobile = _mobileController.text.trim();

    try {
      final referralCode = _referralCodeController.text.trim();
      final profile = await widget.authService.register(
        fullName:     _fullNameController.text.trim(),
        password:     _passwordController.text,
        email:        email.isEmpty  ? null : email,
        mobile:       mobile.isEmpty ? null : mobile,
        countryIso2:  _selectedCountry?.iso2,
        referralCode: referralCode.isEmpty ? null : referralCode,
      );
      if (mounted) widget.onRegisterSuccess(profile);
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
      // Re-validate all fields so server errors render with red borders.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackbar(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackbar('Unable to reach the server. Please check your connection and try again.');
    }
  }

  // ─── Google Sign-In ──────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    if (_googleSigningIn || _submitting) return;
    setState(() => _googleSigningIn = true);
    try {
      final googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) {
        if (mounted) setState(() => _googleSigningIn = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (mounted) {
          setState(() => _googleSigningIn = false);
          _showSnackbar('Google Sign-In failed. Please try again.');
        }
        return;
      }
      final profile = await widget.authService.googleSignIn(idToken);
      if (mounted) widget.onRegisterSuccess(profile);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _googleSigningIn = false);
      _showSnackbar(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _googleSigningIn = false);
      _showSnackbar('Google Sign-In failed. Please try again.');
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
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Country picker ────────────────────────────────────────────
                _SectionLabel(label: 'Country'),
                const SizedBox(height: 8),
                _countriesLoading
                    ? const _CountryLoadingPlaceholder()
                    : CountryPickerField(
                        key: const Key('country_field'),
                        countries: _countries,
                        selected: _selectedCountry,
                        onChanged: _onCountryChanged,
                        enabled: !_submitting,
                        errorText: _serverErrors['country_iso2'],
                      ),
                const SizedBox(height: 16),

                // ── Country blocked banner ────────────────────────────────────
                if (_blockedMessage != null) ...[
                  _BlockedBanner(message: _blockedMessage!),
                  const SizedBox(height: 16),
                ],

                // ── Full Name ─────────────────────────────────────────────────
                AuthTextField(
                  key: const Key('full_name_field'),
                  formFieldKey: _fullNameKey,
                  label: 'Full Name',
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  serverError: _serverErrors['full_name'],
                  onChanged: (_) => _clearServerError('full_name', _fullNameKey),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required.';
                    }
                    if (value.trim().length < 2) {
                      return 'Full name must be at least 2 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Email ─────────────────────────────────────────────────────
                AuthTextField(
                  key: const Key('email_field'),
                  formFieldKey: _emailKey,
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  serverError: _serverErrors['email'],
                  onChanged: (_) => _clearServerError('email', _emailKey),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final email = value.trim();
                    final emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                    if (!emailRe.hasMatch(email)) {
                      return 'Email address is invalid.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Mobile ────────────────────────────────────────────────────
                AuthTextField(
                  key: const Key('mobile_field'),
                  formFieldKey: _mobileKey,
                  label: 'Mobile Number',
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  hintText: _selectedCountry?.phoneExample.isNotEmpty == true
                      ? _selectedCountry!.phoneExample
                      : null,
                  serverError: _serverErrors['mobile'],
                  onChanged: (_) => _clearServerError('mobile', _mobileKey),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final mobile = value.trim();
                    final e164Re = RegExp(r'^\+[1-9]\d{6,14}$');
                    if (!e164Re.hasMatch(mobile)) {
                      return 'Mobile number must include the correct international country code (e.g. ${_selectedCountry?.phoneExample ?? '+11234567890'}).';
                    }
                    if (_selectedCountry != null &&
                        _selectedCountry!.dialCode.isNotEmpty &&
                        !mobile.startsWith(_selectedCountry!.dialCode)) {
                      return 'The phone number does not match the selected country.';
                    }
                    return null;
                  },
                ),
                if (_selectedCountry != null &&
                    _selectedCountry!.phoneExample.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Example for ${_selectedCountry!.name}: ${_selectedCountry!.phoneExample}',
                      style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Password ──────────────────────────────────────────────────
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
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters.';
                    }
                    if (!RegExp(r'[A-Z]').hasMatch(value)) {
                      return 'Password must contain at least one uppercase letter.';
                    }
                    if (!RegExp(r'[a-z]').hasMatch(value)) {
                      return 'Password must contain at least one lowercase letter.';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(value)) {
                      return 'Password must contain at least one number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Referral Code (optional) ──────────────────────────────────
                AuthTextField(
                  key: const Key('referral_code_field'),
                  formFieldKey: _referralCodeKey,
                  label: 'Referral Code (optional)',
                  controller: _referralCodeController,
                  textInputAction: TextInputAction.done,
                  enabled: !_submitting,
                  autocorrect: false,
                  enableSuggestions: false,
                  serverError: _serverErrors['referral_code'],
                  onChanged: (_) => _clearServerError('referral_code', _referralCodeKey),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 28),

                // ── Submit button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('register_button'),
                    onPressed: (_submitting || _blockedMessage != null) ? null : _submit,
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
                const SizedBox(height: 16),

                // ── OR divider ────────────────────────────────────────────
                const Row(
                  children: [
                    Expanded(child: Divider(color: _kBorder)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: _kTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: _kBorder)),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Continue with Google ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('google_sign_in_button'),
                    onPressed: (_submitting || _googleSigningIn)
                        ? null
                        : _signInWithGoogle,
                    icon: _googleSigningIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kPrimary,
                            ),
                          )
                        : const Icon(Icons.g_mobiledata_rounded, size: 22),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: _kBorder, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Login link ────────────────────────────────────────────────
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
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _kTextSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

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
          const Icon(Icons.block_rounded, color: _kError, size: 18),
          const SizedBox(width: 10),
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
