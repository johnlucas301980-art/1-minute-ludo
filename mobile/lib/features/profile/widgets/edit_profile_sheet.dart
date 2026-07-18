import 'package:flutter/material.dart';
import '../../../core/errors/api_exception.dart';
import '../../auth/models/user_profile.dart';
import '../services/profile_service.dart';

// ─── Theme constants ──────────────────────────────────────────────────────────
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Bottom sheet that lets the player edit their display name, country and
/// avatar URL.
///
/// [onSuccess] is called with the updated [UserProfile] when the server
/// confirms the change.  The caller is responsible for updating its state and
/// showing any confirmation feedback before the sheet is dismissed.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.profile,
    required this.profileService,
    required this.onSuccess,
  });

  final UserProfile profile;
  final ProfileService profileService;
  final ValueChanged<UserProfile> onSuccess;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _avatarCtrl;

  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.fullName);
    _countryCtrl = TextEditingController(text: widget.profile.country ?? '');
    _avatarCtrl = TextEditingController(text: widget.profile.avatar ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _countryCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });

    final name = _nameCtrl.text.trim();
    final country =
        _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim();
    final avatar =
        _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim();

    try {
      final updated = await widget.profileService.updateProfile(
        fullName: name,
        country: country,
        avatar: avatar,
      );
      if (mounted) {
        widget.onSuccess(updated);
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

            // ── Title ──────────────────────────────────────────────────────
            const Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),

            // ── Form ───────────────────────────────────────────────────────
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _SheetField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    hint: 'Your display name',
                    icon: Icons.person_outline,
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.length < 2) return 'Name must be at least 2 characters.';
                      if (s.length > 120) return 'Name must be at most 120 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _SheetField(
                    controller: _countryCtrl,
                    label: 'Country',
                    hint: 'e.g. NG (leave blank to clear)',
                    icon: Icons.flag_outlined,
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.length > 100) return 'Country must be at most 100 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _SheetField(
                    controller: _avatarCtrl,
                    label: 'Avatar URL',
                    hint: 'https://… (leave blank to clear)',
                    icon: Icons.image_outlined,
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isNotEmpty &&
                          !s.startsWith('http://') &&
                          !s.startsWith('https://')) {
                        return 'Avatar must be an http/https URL.';
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

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
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
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared form field ────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: _kTextSecondary, fontSize: 13),
        labelStyle: const TextStyle(color: _kTextSecondary),
        prefixIcon: Icon(icon, color: _kPrimary, size: 20),
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
