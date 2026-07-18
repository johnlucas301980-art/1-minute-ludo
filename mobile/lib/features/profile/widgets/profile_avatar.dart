import 'package:flutter/material.dart';

/// Displays a circular player avatar with a gold gradient ring.
///
/// Falls back to the player's initial letter when no avatar URL is set.
/// The gold glow reinforces the arcade theme across the app.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.fullName,
    this.radius = 52.0,
  });

  final String? avatarUrl;
  final String fullName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(255, 215, 0, 0.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3.0),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF1A1A2E),
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
        child: avatarUrl == null
            ? Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: radius * 0.65,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFD700),
                ),
              )
            : null,
      ),
    );
  }
}
