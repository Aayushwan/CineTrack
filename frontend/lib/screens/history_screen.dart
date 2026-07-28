// frontend/lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'All'; // 'All', 'Movies', 'Shows'
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _historyLog = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await ApiService.getWatchHistory();
      if (mounted) {
        setState(() {
          _historyLog = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredHistory {
    if (_selectedFilter == 'Movies') {
      return _historyLog.where((item) => item['type'] == 'Movie').toList();
    } else if (_selectedFilter == 'Shows') {
      return _historyLog.where((item) => item['type'] == 'Show').toList();
    }
    return _historyLog;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredHistory;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Watch History',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${_historyLog.length} Items',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Chips
              Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Movies'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Shows'),
                ],
              ),
              const SizedBox(height: 20),

              // Timeline List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE11D48)),
                      )
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Text(_errorMessage,
                                style: const TextStyle(color: Colors.redAccent)),
                          )
                        : filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No history recorded yet.',
                                  style: TextStyle(color: Colors.white54, fontSize: 15),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchHistory,
                                color: const Color(0xFFE11D48),
                                child: ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    final isShow = item['type'] == 'Show';

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF131316),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: AspectRatio(
                                            aspectRatio: 2 / 3,
                                            child: Image.network(
                                              item['poster'] ?? '',
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Container(color: const Color(0xFF1E293B)),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          item['title'] ?? 'Untitled',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (isShow && item['subtitle'] != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item['subtitle'],
                                                style: const TextStyle(
                                                  color: Color(0xFFE11D48),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time_rounded,
                                                    color: Colors.white38, size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${item['watchedDate']} at ${item['watchedTime']}',
                                                  style: const TextStyle(
                                                      color: Colors.white54, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star_rounded,
                                                    color: Colors.amber, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${item['userRating']}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            const Icon(Icons.chevron_right_rounded,
                                                color: Colors.white24, size: 18),
                                          ],
                                        ),
                                        onTap: () => context.go('/movie/${item['id']}'),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = label);
      },
      selectedColor: const Color(0xFFE11D48),
      backgroundColor: const Color(0xFF131316),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white60,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(color: isSelected ? Colors.transparent : Colors.white10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}