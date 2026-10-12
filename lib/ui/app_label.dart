import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An app as plain text, the only way apps are drawn in this launcher.
class AppLabel extends StatelessWidget {
  const AppLabel({
    super.key,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.fontSize = 24,
    this.textAlign = TextAlign.start,
    this.badge,
    this.expand = false,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double fontSize;
  final TextAlign textAlign;

  /// Small faded tag after the name, e.g. "work" for work-profile apps.
  final String? badge;

  /// Makes the whole row tappable, not just the text. Needs a bounded width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final text = Text.rich(
      TextSpan(
        text: label,
        children: [
          if (badge != null)
            TextSpan(
              text: '  $badge',
              style: TextStyle(
                fontSize: fontSize * 0.5,
                color: color.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w300,
        letterSpacing: 0.2,
        color: color,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onLongPress!();
            },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: fontSize * 0.42),
        child: expand ? SizedBox(width: double.infinity, child: text) : text,
      ),
    );
  }
}
