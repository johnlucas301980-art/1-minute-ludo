import 'package:flutter/material.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kError = Color(0xFFFF4C4C);

/// A styled [TextFormField] for use in authentication screens.
///
/// Consistent with the 1 Minute Ludo Material 3 dark/gold design used across
/// [ProfileScreen] and [WalletScreen].
///
/// Pass [validator] to enable inline validation messages.
/// Pass [onToggleObscure] to show a visibility icon button — intended for
/// password fields where [obscureText] is toggled by the parent state.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleObscure,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.validator,
    this.enabled = true,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;

  /// When non-null, a visibility toggle icon button is shown in the suffix.
  final VoidCallback? onToggleObscure;

  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      enabled: enabled,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kTextSecondary, fontSize: 14),
        filled: true,
        fillColor: _kSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: _kError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kError, width: 1.5),
        ),
        errorStyle: const TextStyle(
          color: _kError,
          fontSize: 12,
          height: 1.4,
        ),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _kTextSecondary,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }
}
