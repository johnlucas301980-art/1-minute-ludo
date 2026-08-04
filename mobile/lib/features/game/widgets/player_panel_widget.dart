import 'dart:math' as math;

import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const Color _kSurface = Color(0xFF1A1A2E);
const Color _kBg      = Color(0xFF0D0D1A);

Color _colorForName(String color) => switch (color) {
      'red'    => const Color(0xFFE53935),
      'blue'   => const Color(0xFF1565C0),
      'yellow' => const Color(0xFFF9A825),
      'green'  => const Color(0xFF2E7D32),
      _        => const Color(0xFF6C63FF),
    };

// ─── Data model ───────────────────────────────────────────────────────────────

class PlayerPanelData {
  const PlayerPanelData({
    required this.name,
    required this.countryFlag,
    required this.playerId,
    required this.color,
    this.avatarUrl,
  });

  final String  name;
  final String  countryFlag; // e.g. "🇮🇳"
  final String  playerId;    // e.g. "#A3F7"
  final String  color;       // 'red' | 'blue' | 'yellow' | 'green'
  final String? avatarUrl;
}

// ─── PlayerPanelWidget ────────────────────────────────────────────────────────

/// Player info panel with animated 18-second glowing-snake countdown border.
///
/// [isMyPanel]  — when true shows "YOU" instead of [data.name].
/// [isActive]   — when true the border snake animates (current turn).
/// [playerCount]— used externally to decide visibility; not used internally.
/// [onEmoji]    — callback when the emoji quick-send button is pressed.
class PlayerPanelWidget extends StatefulWidget {
  const PlayerPanelWidget({
    super.key,
    required this.data,
    required this.isMyPanel,
    required this.isActive,
    this.onEmoji,
  });

  final PlayerPanelData data;
  final bool            isMyPanel;
  final bool            isActive;
  final VoidCallback?   onEmoji;

  @override
  State<PlayerPanelWidget> createState() => _PlayerPanelWidgetState();
}

class _PlayerPanelWidgetState extends State<PlayerPanelWidget>
    with TickerProviderStateMixin {
  // Snake countdown: 0→1 over 18 seconds (0 = full, 1 = empty).
  late final AnimationController _timerCtrl;
  // Glow pulse: loops while active.
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    if (widget.isActive) _timerCtrl.forward();
  }

  @override
  void didUpdateWidget(PlayerPanelWidget old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _timerCtrl
        ..reset()
        ..forward();
    } else if (!widget.isActive && old.isActive) {
      _timerCtrl.stop();
    }
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor => _colorForName(widget.data.color);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_timerCtrl, _pulseAnim]),
      builder: (context, child) {
        final progress = 1.0 - _timerCtrl.value; // 1=full, 0=empty
        final pulse    = _pulseAnim.value;
        final isActive = widget.isActive;

        return CustomPaint(
          painter: _SnakeBorderPainter(
            color:      _accentColor,
            progress:   progress,
            isActive:   isActive,
            pulseValue: pulse,
            radius:     12,
          ),
          child: child,
        );
      },
      child: _PanelContent(
        data:      widget.data,
        isMyPanel: widget.isMyPanel,
        isActive:  widget.isActive,
        onEmoji:   widget.onEmoji,
      ),
    );
  }
}

// ─── Panel content ────────────────────────────────────────────────────────────

class _PanelContent extends StatelessWidget {
  const _PanelContent({
    required this.data,
    required this.isMyPanel,
    required this.isActive,
    required this.onEmoji,
  });

  final PlayerPanelData data;
  final bool            isMyPanel;
  final bool            isActive;
  final VoidCallback?   onEmoji;

  Color get _accent => _colorForName(data.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top row: avatar + name/YOU + LIVE ──────────────────────────────
          Row(
            children: [
              _Avatar(data: data, size: 36),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name or YOU
                    Text(
                      isMyPanel ? 'YOU' : data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:      isMyPanel ? _accent : Colors.white,
                        fontSize:   isMyPanel ? 13 : 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Flag + Player ID
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.countryFlag,
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          data.playerId,
                          style: const TextStyle(
                            color:     Color(0xFF9E9E9E),
                            fontSize:  10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // LIVE badge + Emoji button stacked
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LiveBadge(isActive: isActive),
                  const SizedBox(height: 4),
                  _EmojiButton(onPressed: onEmoji),
                ],
              ),
            ],
          ),
          // ── Colour indicator strip ─────────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  _accent.withAlpha(isActive ? 220 : 80),
                  _accent.withAlpha(isActive ? 120 : 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.data, required this.size});

  final PlayerPanelData data;
  final double          size;

  @override
  Widget build(BuildContext context) {
    final accent   = _colorForName(data.color);
    final initials = data.name.trim().isEmpty
        ? '?'
        : data.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
            .join();

    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
        color: _kBg,
      ),
      child: ClipOval(
        child: data.avatarUrl != null
            ? Image.network(
                data.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialsWidget(initials, accent, size),
              )
            : _initialsWidget(initials, accent, size),
      ),
    );
  }

  Widget _initialsWidget(String initials, Color accent, double size) {
    return Container(
      color: accent.withAlpha(40),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color:      accent,
            fontSize:   size * 0.32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─── LIVE badge ───────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF4CAF50).withAlpha(30)
            : Colors.transparent,
        border: Border.all(
          color: isActive
              ? const Color(0xFF4CAF50)
              : const Color(0xFF424242),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF424242),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'LIVE',
            style: TextStyle(
              color: isActive
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF616161),
              fontSize:   7,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Emoji button ─────────────────────────────────────────────────────────────

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width:  26,
        height: 26,
        decoration: BoxDecoration(
          color:        const Color(0xFF2D2D4E),
          shape:        BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF3D3D6E),
            width: 1,
          ),
        ),
        child: const Center(
          child: Text('😊', style: TextStyle(fontSize: 13)),
        ),
      ),
    );
  }
}

// ─── Snake border painter ─────────────────────────────────────────────────────

/// Draws a glowing snake arc around the panel border.
///
/// [progress]   — 1.0 = full border (start of turn), 0.0 = empty.
/// [isActive]   — current player glows brighter.
/// [pulseValue] — drives glow pulsing (0.0–1.0, from AnimationController).
class _SnakeBorderPainter extends CustomPainter {
  const _SnakeBorderPainter({
    required this.color,
    required this.progress,
    required this.isActive,
    required this.pulseValue,
    required this.radius,
  });

  final Color  color;
  final double progress;
  final bool   isActive;
  final double pulseValue;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive && progress >= 1.0) {
      // Inactive: draw a simple dim border only
      _drawSimpleBorder(canvas, size);
      return;
    }

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    // ── Glow layers (outer → inner) ──────────────────────────────────────────
    final baseAlpha = isActive ? (180 + (pulseValue * 55).toInt()).clamp(0, 255) : 120;
    final glowWidth = isActive ? (4.5 + pulseValue * 2.5) : 3.0;

    // Outer soft glow
    if (isActive) {
      final outerGlow = Paint()
        ..color = color.withAlpha((baseAlpha * 0.4).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth * 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      _drawArc(canvas, rect, size, outerGlow);
    }

    // Mid glow
    final midGlow = Paint()
      ..color = color.withAlpha((baseAlpha * 0.65).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth * 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    _drawArc(canvas, rect, size, midGlow);

    // Core bright line
    final corePaint = Paint()
      ..color = color.withAlpha(baseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth * 0.7
      ..strokeCap = StrokeCap.round;
    _drawArc(canvas, rect, size, corePaint);

    // ── Bright head dot ──────────────────────────────────────────────────────
    if (isActive && progress > 0.02) {
      final headPos = _headOffset(size, progress);
      final headPaint = Paint()
        ..color = Colors.white.withAlpha((200 + (pulseValue * 55).toInt()).clamp(0, 255))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(headPos, glowWidth * 0.65, headPaint);
      canvas.drawCircle(
        headPos,
        glowWidth * 0.4,
        Paint()..color = Colors.white.withAlpha(230),
      );
    }
  }

  // Draw only the progress arc along the rounded-rect perimeter.
  void _drawArc(Canvas canvas, RRect rrect, Size size, Paint paint) {
    if (progress <= 0) return;

    // Approximate the rounded-rect perimeter as a path and trim it.
    // We start at the top-left and go clockwise, covering [progress] fraction.
    final path = Path()..addRRect(rrect);

    // Use PathMetrics to trim the path.
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric     = metrics.first;
    final totalLen   = metric.length;
    final snakeLen   = totalLen * progress;

    final extracted = metric.extractPath(0, snakeLen);
    canvas.drawPath(extracted, paint);
  }

  // Returns the pixel position at the HEAD of the snake (end of the arc).
  Offset _headOffset(Size size, double progress) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path    = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return Offset.zero;
    final metric  = metrics.first;
    final len     = metric.length * progress;
    final tangent = metric.getTangentForOffset(len.clamp(0, metric.length));
    return tangent?.position ?? Offset.zero;
  }

  void _drawSimpleBorder(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color.withAlpha(60)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SnakeBorderPainter old) =>
      old.progress   != progress   ||
      old.isActive   != isActive   ||
      old.pulseValue != pulseValue ||
      old.color      != color;
}
