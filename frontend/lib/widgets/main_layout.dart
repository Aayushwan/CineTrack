// frontend/lib/widgets/main_layout.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static const Color _background = Color(0xFF08080B);
  static const Color _sidebarSurface = Color(0xFF121216);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final String currentRoute = GoRouterState.of(context).uri.toString();

    return Scaffold(
      backgroundColor: _background,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: _isExpanded ? 252 : 82,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: _background,
              border: Border(
                right: BorderSide(color: Colors.white.withValues(alpha: 0.055)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(10, 0),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: _SidebarBackground()),
                Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: _isExpanded ? 224 : 60,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: _isExpanded ? 9 : 6,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _sidebarSurface.withValues(
                                      alpha: 0.94,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      _isExpanded ? 22 : 30,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.065,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.24,
                                        ),
                                        blurRadius: 26,
                                        offset: const Offset(0, 13),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: _isExpanded
                                        ? CrossAxisAlignment.start
                                        : CrossAxisAlignment.center,
                                    children: [
                                      if (_isExpanded)
                                        const _SidebarSectionLabel(
                                          label: 'BROWSE',
                                        ),
                                      _SidebarNavItem(
                                        icon: Icons.search_rounded,
                                        label: 'Search',
                                        route: '/search',
                                        currentRoute: currentRoute,
                                        isExpanded: _isExpanded,
                                      ),
                                      _SidebarNavItem(
                                        icon: Icons.home_outlined,
                                        activeIcon: Icons.home_rounded,
                                        label: 'Home',
                                        route: '/',
                                        currentRoute: currentRoute,
                                        isExpanded: _isExpanded,
                                        subItems: _isExpanded
                                            ? [
                                                const _SubNavItem(
                                                  label: 'Continue Watching',
                                                  route: '/',
                                                ),
                                                const _SubNavItem(
                                                  label: 'Calendar',
                                                  route: '/calendar',
                                                ),
                                                const _SubNavItem(
                                                  label: 'Recommended',
                                                  route: '/recommended',
                                                ),
                                              ]
                                            : null,
                                      ),
                                      _SidebarNavItem(
                                        icon: Icons.auto_awesome_outlined,
                                        activeIcon: Icons.auto_awesome_rounded,
                                        label: 'Discover',
                                        route: '/discover',
                                        currentRoute: currentRoute,
                                        isExpanded: _isExpanded,
                                        subItems: _isExpanded
                                            ? [
                                                const _SubNavItem(
                                                  label: 'Trending',
                                                  route: '/discover/trending',
                                                ),
                                                const _SubNavItem(
                                                  label: 'Releases',
                                                  route: '/releases',
                                                ),
                                                const _SubNavItem(
                                                  label: 'Anticipated',
                                                  route:
                                                      '/discover/anticipated',
                                                ),
                                                const _SubNavItem(
                                                  label: 'Popular',
                                                  route: '/discover/popular',
                                                ),
                                              ]
                                            : null,
                                      ),
                                      if (_isExpanded)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 9,
                                          ),
                                          child: Divider(
                                            color: Colors.white10,
                                            height: 1,
                                          ),
                                        ),
                                      if (_isExpanded)
                                        const _SidebarSectionLabel(
                                          label: 'LIBRARY',
                                        ),
                                      _SidebarNavItem(
                                        icon:
                                            Icons.format_list_bulleted_rounded,
                                        activeIcon:
                                            Icons.featured_play_list_rounded,
                                        label: 'Lists',
                                        route: '/lists',
                                        currentRoute: currentRoute,
                                        isExpanded: _isExpanded,
                                        subItems: _isExpanded
                                            ? [
                                                const _SubNavItem(
                                                  label: 'Watchlist',
                                                  route: '/watchlist',
                                                ),
                                                const _SubNavItem(
                                                  label: 'My Lists',
                                                  route: '/lists',
                                                ),
                                              ]
                                            : null,
                                      ),
                                      _SidebarNavItem(
                                        icon: Icons.history_outlined,
                                        activeIcon: Icons.history_rounded,
                                        label: 'History',
                                        route: '/history',
                                        currentRoute: currentRoute,
                                        isExpanded: _isExpanded,
                                      ),
                                      _SidebarNavItem(
                                        icon: Icons.person_outline_rounded,
                                        activeIcon: Icons.person_rounded,
                                        label: 'Profile',
                                        route: '/profile',
                                        currentRoute: currentRoute,
                                        isExpanded: _isExpanded,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildFooter(),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: ClipRect(child: widget.child)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: 86,
      padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 18 : 13),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: _isExpanded ? 'Collapse menu' : 'Expand menu',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_lightPurple, _darkPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _purple.withValues(alpha: 0.28),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      turns: _isExpanded ? 0 : 0.5,
                      child: Icon(
                        _isExpanded
                            ? Icons.menu_open_rounded
                            : Icons.menu_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(width: 12),
              const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CineTrack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.65,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'YOUR PERSONAL CINEMA',
                    style: TextStyle(
                      color: _lightPurple,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.fromLTRB(
        _isExpanded ? 14 : 11,
        10,
        _isExpanded ? 14 : 11,
        16,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 12 : 0,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: _sidebarSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(_isExpanded ? 16 : 24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _purple.withValues(alpha: 0.17)),
              ),
              child: const Icon(
                Icons.movie_filter_outlined,
                color: _lightPurple,
                size: 17,
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CineTrack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track every story',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.32),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarBackground extends StatelessWidget {
  const _SidebarBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const ColoredBox(color: Color(0xFF08080B), child: SizedBox.expand()),
          Positioned(
            top: -100,
            left: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB143EB).withValues(alpha: 0.11),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -150,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8431D9).withValues(alpha: 0.065),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  final String label;

  const _SidebarSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 7),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.28),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String route;
  final String currentRoute;
  final bool isExpanded;
  final List<_SubNavItem>? subItems;

  const _SidebarNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.isExpanded,
    this.subItems,
  });

  @override
  State<_SidebarNavItem> createState() {
    return _SidebarNavItemState();
  }
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);

  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isActiveRoute {
    if (widget.currentRoute == widget.route) {
      return true;
    }

    if (widget.subItems != null) {
      return widget.subItems!.any((sub) => widget.currentRoute == sub.route);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted = _isActiveRoute || _isHovered || _isPressed;

    final Color currentColor = _isActiveRoute
        ? _lightPurple
        : isHighlighted
        ? Colors.white
        : Colors.white.withValues(alpha: 0.68);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Tooltip(
            message: widget.isExpanded ? '' : widget.label,
            child: MouseRegion(
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
                  onTap: () => context.go(widget.route),
                  onHighlightChanged: (pressed) {
                    setState(() {
                      _isPressed = pressed;
                    });
                  },
                  borderRadius: BorderRadius.circular(
                    widget.isExpanded ? 12 : 24,
                  ),
                  splashColor: _purple.withValues(alpha: 0.16),
                  highlightColor: _purple.withValues(alpha: 0.08),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOut,
                    height: 43,
                    alignment: widget.isExpanded
                        ? Alignment.centerLeft
                        : Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isExpanded ? 10 : 0,
                    ),
                    decoration: BoxDecoration(
                      gradient: _isActiveRoute
                          ? LinearGradient(
                              colors: [
                                _purple.withValues(alpha: 0.18),
                                _purple.withValues(alpha: 0.07),
                              ],
                            )
                          : null,
                      color: _isActiveRoute
                          ? null
                          : _isHovered
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        widget.isExpanded ? 12 : 24,
                      ),
                      border: Border.all(
                        color: _isActiveRoute
                            ? _purple.withValues(alpha: 0.22)
                            : Colors.transparent,
                      ),
                      boxShadow: _isActiveRoute
                          ? [
                              BoxShadow(
                                color: _purple.withValues(alpha: 0.08),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: widget.isExpanded
                          ? Alignment.centerLeft
                          : Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 170),
                            width: 29,
                            height: 29,
                            decoration: BoxDecoration(
                              color: _isActiveRoute
                                  ? _purple.withValues(alpha: 0.16)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              _isActiveRoute
                                  ? widget.activeIcon ?? widget.icon
                                  : widget.icon,
                              color: currentColor,
                              size: 19,
                            ),
                          ),
                          if (widget.isExpanded) ...[
                            const SizedBox(width: 10),
                            Text(
                              widget.label,
                              style: TextStyle(
                                color: currentColor,
                                fontSize: 12,
                                fontWeight: _isActiveRoute
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            if (_isActiveRoute) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: _lightPurple,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.isExpanded && widget.subItems != null)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 2, bottom: 5),
            child: Stack(
              children: [
                Positioned(
                  top: 2,
                  bottom: 2,
                  left: 7,
                  child: Container(
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.075),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: widget.subItems!.map((sub) {
                      final bool isSubActive = widget.currentRoute == sub.route;

                      return _SubItemTile(
                        label: sub.label,
                        route: sub.route,
                        isActive: isSubActive,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SubNavItem {
  final String label;
  final String route;

  const _SubNavItem({required this.label, required this.route});
}

class _SubItemTile extends StatefulWidget {
  final String label;
  final String route;
  final bool isActive;

  const _SubItemTile({
    required this.label,
    required this.route,
    required this.isActive,
  });

  @override
  State<_SubItemTile> createState() => _SubItemTileState();
}

class _SubItemTileState extends State<_SubItemTile> {
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);

  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted = widget.isActive || _isHovered || _isPressed;

    final Color textColor = widget.isActive
        ? _lightPurple
        : isHighlighted
        ? Colors.white.withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.42);

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
          onTap: () => context.go(widget.route),
          onHighlightChanged: (pressed) {
            setState(() {
              _isPressed = pressed;
            });
          },
          borderRadius: BorderRadius.circular(9),
          splashColor: _purple.withValues(alpha: 0.14),
          highlightColor: _purple.withValues(alpha: 0.07),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? _purple.withValues(alpha: 0.08)
                  : _isHovered
                  ? Colors.white.withValues(alpha: 0.025)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: widget.isActive ? 5 : 4,
                  height: widget.isActive ? 5 : 4,
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? _lightPurple
                        : Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    boxShadow: widget.isActive
                        ? [
                            BoxShadow(
                              color: _purple.withValues(alpha: 0.45),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: widget.isActive
                        ? FontWeight.w800
                        : FontWeight.w600,
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
