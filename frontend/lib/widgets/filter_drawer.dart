// frontend/lib/widgets/filter_drawer.dart

import 'package:flutter/material.dart';

class FilterDrawer extends StatefulWidget {
  final String selectedGenre;
  final String selectedStatus;
  final String selectedDecade;
  final Function(String genre, String status, String decade) onApply;
  final VoidCallback onReset;

  const FilterDrawer({
    super.key,
    required this.selectedGenre,
    required this.selectedStatus,
    required this.selectedDecade,
    required this.onApply,
    required this.onReset,
  });

  static const Map<String, int> genreMap = {
    'Action': 28,
    'Adventure': 12,
    'Animation': 16,
    'Comedy': 35,
    'Crime': 80,
    'Documentary': 99,
    'Drama': 18,
    'Family': 10749,
    'Fantasy': 14,
    'Horror': 27,
    'Mystery': 9648,
    'Romance': 10749,
    'Sci-Fi': 878,
    'Thriller': 53,
  };

  static const List<String> statuses = ['All', 'Released', 'Upcoming'];

  static const List<String> decades = [
    'All',
    'This Year',
    '2020s',
    '2010s',
    '2000s',
    '1990s',
    '1980s',
    '1970s',
    '1960s',
    'Before 1960',
  ];

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  static const Color _background = Color(0xFF0D0D11);
  static const Color _surface = Color(0xFF16151B);
  static const Color _inputSurface = Color(0xFF101014);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

  late String _genre;
  late String _status;
  late String _decade;

  @override
  void initState() {
    super.initState();

    _genre = widget.selectedGenre;
    _status = widget.selectedStatus;
    _decade = widget.selectedDecade;
  }

  int get _activeFilterCount {
    int count = 0;

    if (_genre != 'All') count++;
    if (_status != 'All') count++;
    if (_decade != 'All') count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 340,
      elevation: 24,
      backgroundColor: _background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _FilterDrawerBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      _buildOverviewCard(),
                      const SizedBox(height: 24),
                      _buildFilterSection(
                        number: '01',
                        label: 'Genre',
                        description:
                            'Choose the type of story you want to explore.',
                        icon: Icons.theaters_outlined,
                        child: _buildDropdown(
                          value: _genre,
                          items: ['All', ...FilterDrawer.genreMap.keys],
                          icon: Icons.movie_filter_outlined,
                          onChanged: (value) {
                            setState(() {
                              _genre = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildFilterSection(
                        number: '02',
                        label: 'Release status',
                        description:
                            'Browse titles that are available or coming soon.',
                        icon: Icons.schedule_rounded,
                        child: _buildDropdown(
                          value: _status,
                          items: FilterDrawer.statuses,
                          icon: Icons.event_available_outlined,
                          onChanged: (value) {
                            setState(() {
                              _status = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildFilterSection(
                        number: '03',
                        label: 'Decade',
                        description:
                            'Narrow results to a specific release period.',
                        icon: Icons.calendar_month_outlined,
                        child: _buildDropdown(
                          value: _decade,
                          items: FilterDrawer.decades,
                          icon: Icons.history_rounded,
                          onChanged: (value) {
                            setState(() {
                              _decade = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 17, 12, 17),
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.86),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_lightPurple, _darkPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: 0.26),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.55,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _activeFilterCount == 0
                      ? 'Refine what you want to see'
                      : '$_activeFilterCount '
                            '${_activeFilterCount == 1 ? 'filter' : 'filters'} selected',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close filters',
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.65),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF201128), Color(0xFF151219)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purple.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.11),
              shape: BoxShape.circle,
              border: Border.all(color: _purple.withValues(alpha: 0.16)),
            ),
            child: Text(
              '$_activeFilterCount',
              style: const TextStyle(
                color: _lightPurple,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _activeFilterCount == 0
                      ? 'Showing the complete catalog'
                      : 'Your results will match these selections',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            _activeFilterCount > 0
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
            color: _activeFilterCount > 0
                ? _lightPurple
                : Colors.white.withValues(alpha: 0.25),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String number,
    required String label,
    required String description,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _purple.withValues(alpha: 0.14)),
                ),
                child: Icon(icon, color: _lightPurple, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                number,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.34),
              fontSize: 9,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final validValue = items.contains(value) ? value : 'All';

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: _inputSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: validValue != 'All'
              ? _purple.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.075),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: const Color(0xFF1A191F),
          menuMaxHeight: 350,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: validValue != 'All'
                ? _lightPurple
                : Colors.white.withValues(alpha: 0.42),
            size: 21,
          ),
          items: items.map((item) {
            final isSelected = item == validValue;

            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected && item != 'All'
                        ? _lightPurple
                        : Colors.white.withValues(alpha: 0.3),
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isSelected && item != 'All')
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _lightPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                widget.onReset();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 17),
              label: const Text(
                'Reset',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                widget.onApply(_genre, _status, _decade);

                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text(
                'Apply filters',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDrawerBackground extends StatelessWidget {
  const _FilterDrawerBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const ColoredBox(color: Color(0xFF0D0D11), child: SizedBox.expand()),
          Positioned(
            top: -130,
            right: -150,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB143EB).withValues(alpha: 0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -170,
            left: -170,
            child: Container(
              width: 380,
              height: 380,
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
