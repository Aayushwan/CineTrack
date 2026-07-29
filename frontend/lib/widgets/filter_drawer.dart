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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF131316),
      width: 320,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drawer Header ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 24),

              // ── Dropdown Selectors ──────────────────────────────────────────
              Expanded(
                child: ListView(
                  children: [
                    _buildLabel('Genre'),
                    _buildDropdown(
                      value: _genre,
                      items: ['All', ...FilterDrawer.genreMap.keys],
                      onChanged: (val) => setState(() => _genre = val!),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Status'),
                    _buildDropdown(
                      value: _status,
                      items: FilterDrawer.statuses,
                      onChanged: (val) => setState(() => _status = val!),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Decade'),
                    _buildDropdown(
                      value: _decade,
                      items: FilterDrawer.decades,
                      onChanged: (val) => setState(() => _decade = val!),
                    ),
                  ],
                ),
              ),

              // ── Reset & Apply Action Buttons ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onReset();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(_genre, _status, _decade);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA855F7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : 'All',
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}