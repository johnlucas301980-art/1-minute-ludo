import 'package:flutter/material.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kSurface        = Color(0xFF1A1A2E);
const _kPrimary        = Color(0xFF6C63FF);
const _kBorder         = Color(0xFF2D2D4E);
const _kTextSecondary  = Color(0xFF9E9E9E);
const _kError          = Color(0xFFFF4C4C);

/// A styled [TextFormField] for use in authentication screens.
///
/// Pass [validator] for client-side inline validation (red border + text
/// below the field via the Form machinery).
///
/// Pass [serverError] to surface a server-returned field error with the same
/// red-border treatment.  When non-null, [serverError] takes priority over
/// [validator] — the border turns red and the text appears below the field.
/// Clear it (by calling setState with null) when the user starts typing so
/// the error disappears immediately.
///
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
    this.serverError,
    this.onChanged,
    this.hintText,
    this.prefixText,
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

  /// Server-returned field error.  When set, overrides [validator] and shows
  /// with a red border.  Parent should clear this on [onChanged].
  final String? serverError;

  /// Called whenever the field value changes.
  final ValueChanged<String>? onChanged;

  /// Optional hint text shown when the field is empty.
  final String? hintText;

  /// Optional prefix text (e.g. dial code) shown before the user's input.
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    // When a server error is present it overrides the regular validator so the
    // red border and text appear without requiring a form re-submission.
    final effectiveValidator = serverError != null
        ? (String? _) => serverError
        : validator;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      enabled: enabled,
      validator: effectiveValidator,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kTextSecondary, fontSize: 14),
        hintText: hintText,
        hintStyle: const TextStyle(color: _kTextSecondary, fontSize: 14),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: _kPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
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
