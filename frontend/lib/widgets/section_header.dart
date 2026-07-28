// frontend/lib/widgets/section_header.dart
import 'package:flutter/material.dart';

class SectionHeader extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const SectionHeader({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  State<SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<SectionHeader> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // White by default, Red (#E11D48) on press/click
    final currentColor = _isPressed ? const Color(0xFFE11D48) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (isHighlighted) {
          setState(() {
            _isPressed = isHighlighted;
          });
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: const Color(0xFFE11D48).withValues(alpha: 0.2),
        highlightColor: const Color(0xFFE11D48).withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_circle_up_outlined, color: currentColor, size: 22),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: currentColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: currentColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}