// frontend/lib/widgets/section_header.dart

import 'package:flutter/material.dart';

class SectionHeader extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const SectionHeader({super.key, required this.title, required this.onTap});

  @override
  State<SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<SectionHeader> {
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);

  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isHovered || _isPressed;

    final Color titleColor = isActive ? _lightPurple : Colors.white;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (isHighlighted) {
            setState(() {
              _isPressed = isHighlighted;
            });
          },
          borderRadius: BorderRadius.circular(10),
          splashColor: _purple.withValues(alpha: 0.14),
          highlightColor: _purple.withValues(alpha: 0.07),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? _purple.withValues(alpha: 0.045)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  width: 4,
                  height: isActive ? 24 : 19,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_lightPurple, _purple],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: _purple.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _purple.withValues(alpha: 0.13)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? _purple.withValues(alpha: 0.24)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'VIEW ALL',
                        style: TextStyle(
                          color: isActive
                              ? _lightPurple
                              : Colors.white.withValues(alpha: 0.42),
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.75,
                        ),
                      ),
                      const SizedBox(width: 5),
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 170),
                        curve: Curves.easeOut,
                        offset: isActive ? const Offset(0.12, 0) : Offset.zero,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: isActive
                              ? _lightPurple
                              : Colors.white.withValues(alpha: 0.42),
                          size: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
