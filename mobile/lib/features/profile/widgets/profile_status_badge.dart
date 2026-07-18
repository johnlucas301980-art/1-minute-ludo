import 'package:flutter/material.dart';

/// A colour-coded pill badge that shows the player's account status.
///
/// Active → green, Suspended / Banned → red, Unknown → grey.
class ProfileStatusBadge extends StatelessWidget {
  const ProfileStatusBadge({super.key, required this.status});

  final String status;

  Color get _color {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF4CAF50);
      case 'suspended':
      case 'banned':
        return const Color(0xFFFF4C4C);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String get _label =>
      status.isEmpty ? status : status[0].toUpperCase() + status.substring(1);

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            _label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
