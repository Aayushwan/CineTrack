// frontend/lib/screens/lists_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../widgets/movie_card.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  static const Color _background = Color(0xFF08080B);
  static const Color _surface = Color(0xFF141419);
  static const Color _elevatedSurface = Color(0xFF1A191F);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);
  static const Color _danger = Color(0xFFFF647C);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WatchlistProvider>(context, listen: false).fetchCustomLists();
    });
  }

  void _showCreateListModal(WatchlistProvider provider) {
    final TextEditingController titleController = TextEditingController();
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogHeader(
                      context: dialogContext,
                      icon: Icons.playlist_add_rounded,
                      title: 'Create new list',
                      description:
                          'Build a collection for the movies and shows you love.',
                    ),
                    const SizedBox(height: 22),
                    _buildListTitleField(
                      controller: titleController,
                      hintText: 'Enter list title',
                      autofocus: true,
                      onSubmitted: (_) {},
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _purple,
                              disabledBackgroundColor: _purple.withValues(
                                alpha: 0.35,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final title = titleController.text.trim();

                                    if (title.isNotEmpty) {
                                      setModalState(() {
                                        isSubmitting = true;
                                      });

                                      try {
                                        await provider.createList(title);

                                        if (!dialogContext.mounted) return;

                                        Navigator.pop(dialogContext);
                                      } catch (e) {
                                        if (!dialogContext.mounted) return;

                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
                                          _buildSnackBar(
                                            'Failed: $e',
                                            isError: true,
                                          ),
                                        );

                                        setModalState(() {
                                          isSubmitting = false;
                                        });
                                      }
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 7),
                                      Text(
                                        'Create list',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(titleController.dispose);
  }

  void _showRenameListModal(
    WatchlistProvider provider,
    int listId,
    String currentName,
  ) {
    final TextEditingController titleController = TextEditingController(
      text: currentName,
    );

    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogHeader(
                      context: dialogContext,
                      icon: Icons.edit_rounded,
                      title: 'Rename list',
                      description:
                          'Give this collection a new, memorable name.',
                    ),
                    const SizedBox(height: 22),
                    _buildListTitleField(
                      controller: titleController,
                      hintText: 'Enter new list title',
                      autofocus: true,
                      onSubmitted: (_) {},
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _purple,
                              disabledBackgroundColor: _purple.withValues(
                                alpha: 0.35,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final title = titleController.text.trim();

                                    if (title.isNotEmpty &&
                                        title != currentName) {
                                      setModalState(() {
                                        isSubmitting = true;
                                      });

                                      try {
                                        await provider.renameList(
                                          listId,
                                          title,
                                        );

                                        if (!dialogContext.mounted) return;

                                        Navigator.pop(dialogContext);
                                      } catch (e) {
                                        if (!dialogContext.mounted) return;

                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
                                          _buildSnackBar(
                                            'Failed: $e',
                                            isError: true,
                                          ),
                                        );

                                        setModalState(() {
                                          isSubmitting = false;
                                        });
                                      }
                                    } else {
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 7),
                                      Text(
                                        'Save changes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(titleController.dispose);
  }

  void _showDeleteListConfirmation(
    WatchlistProvider provider,
    int listId,
    String title,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _danger.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _danger.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: _danger,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete list?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'This action cannot be undone.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.025),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    'Are you sure you want to delete "$title"?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Keep list',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          provider.deleteList(listId);
                          Navigator.pop(dialogContext);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _danger,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Delete list',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showListDetailsModal(
    WatchlistProvider provider,
    int listId,
    String listTitle,
    List<dynamic> items,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (dialogContext) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final screenHeight = MediaQuery.sizeOf(dialogContext).height;
        final isWide = screenWidth >= 800;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 12,
            vertical: isWide ? 30 : 16,
          ),
          child: Container(
            width: isWide ? screenWidth * 0.85 : screenWidth * 0.96,
            height: screenHeight * 0.88,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.46),
                  blurRadius: 44,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 17),
                    decoration: BoxDecoration(
                      color: _elevatedSurface.withValues(alpha: 0.85),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
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
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.video_library_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                listTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${items.length} '
                                '${items.length == 1 ? 'title' : 'titles'} in this collection',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? _buildModalEmptyState()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              double maxExtent = 175;
                              double aspectRatio = 0.56;

                              if (constraints.maxWidth >= 900) {
                                maxExtent = 205;
                                aspectRatio = 0.59;
                              } else if (constraints.maxWidth >= 600) {
                                maxExtent = 190;
                                aspectRatio = 0.58;
                              }

                              return GridView.builder(
                                padding: const EdgeInsets.all(20),
                                gridDelegate:
                                    SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: maxExtent,
                                      childAspectRatio: aspectRatio,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 20,
                                    ),
                                itemCount: items.length,
                                itemBuilder: (gridContext, index) {
                                  final item = items[index];

                                  final rawId = item is Map
                                      ? (item['id'] ??
                                            item['movie_id'] ??
                                            item['media_id'])
                                      : 0;

                                  return Stack(
                                    children: [
                                      Positioned.fill(
                                        child: GestureDetector(
                                          onTapDown: (_) {
                                            Navigator.pop(dialogContext);
                                          },
                                          child: _buildMovieCardFromItem(
                                            item,
                                            hideActionMenu: true,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 7,
                                        right: 7,
                                        child: Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF0B0A0E,
                                            ).withValues(alpha: 0.82),
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.3,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: PopupMenuButton<String>(
                                            tooltip: 'List options',
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.more_horiz_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            color: _elevatedSurface,
                                            surfaceTintColor: _elevatedSurface,
                                            elevation: 18,
                                            offset: const Offset(0, 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              side: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                            onSelected: (value) async {
                                              if (value == 'remove') {
                                                Navigator.pop(dialogContext);

                                                try {
                                                  await provider
                                                      .removeItemFromList(
                                                        listId,
                                                        rawId,
                                                      );

                                                  // Changed from !mounted to !context.mounted
                                                  if (!context.mounted) return;

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    _buildSnackBar(
                                                      'Item removed from list',
                                                    ),
                                                  );
                                                } catch (e) {
                                                  // Changed from !mounted to !context.mounted
                                                  if (!context.mounted) return;

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    _buildSnackBar(
                                                      'Failed to remove: $e',
                                                      isError: true,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            itemBuilder: (context) {
                                              return [
                                                PopupMenuItem<String>(
                                                  value: 'remove',
                                                  height: 46,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 30,
                                                        height: 30,
                                                        decoration: BoxDecoration(
                                                          color: _danger
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: const Icon(
                                                          Icons
                                                              .remove_circle_outline_rounded,
                                                          color: _danger,
                                                          size: 17,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 11),
                                                      const Text(
                                                        'Remove from list',
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFFFF8A9A,
                                                          ),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ];
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    final totalItems = watchlistProvider.customLists.fold<int>(0, (
      total,
      listData,
    ) {
      final items =
          (listData['items'] ?? listData['posters'] ?? []) as List<dynamic>;

      return total + items.length;
    });

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          const Positioned.fill(child: _ListsBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildPageHeader(
                  provider: watchlistProvider,
                  totalItems: totalItems,
                ),
                Expanded(
                  child: watchlistProvider.customLists.isEmpty
                      ? _buildEmptyState(
                          'No custom lists created yet. Create one to organize your favorite stories.',
                          onCreate: () {
                            _showCreateListModal(watchlistProvider);
                          },
                        )
                      : RefreshIndicator(
                          color: _lightPurple,
                          backgroundColor: _surface,
                          onRefresh: watchlistProvider.fetchCustomLists,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                            itemCount: watchlistProvider.customLists.length,
                            itemBuilder: (context, index) {
                              final listData =
                                  watchlistProvider.customLists[index];

                              final listId = listData['id'];

                              final listTitle =
                                  listData['name'] ??
                                  listData['title'] ??
                                  'Untitled';

                              final List<dynamic> items =
                                  (listData['items'] ??
                                          listData['posters'] ??
                                          [])
                                      as List<dynamic>;

                              return _buildListSection(
                                provider: watchlistProvider,
                                listId: listId,
                                listTitle: listTitle,
                                items: items,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader({
    required WatchlistProvider provider,
    required int totalItems,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 18),
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.84),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_lightPurple, _darkPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: 0.26),
                  blurRadius: 24,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: const Icon(
              Icons.video_library_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Lists',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _lightPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '${provider.customLists.length} '
                        '${provider.customLists.length == 1 ? 'collection' : 'collections'}'
                        ' · $totalItems '
                        '${totalItems == 1 ? 'title' : 'titles'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.46),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showCreateListModal(provider),
              borderRadius: BorderRadius.circular(13),
              child: Ink(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_purple, _darkPurple],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: _darkPurple.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 7),
                    Text(
                      'New list',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection({
    required WatchlistProvider provider,
    required int listId,
    required String listTitle,
    required List<dynamic> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _showListDetailsModal(provider, listId, listTitle, items);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 8, 13),
                  child: Row(
                    children: [
                      Container(
                        width: 41,
                        height: 41,
                        decoration: BoxDecoration(
                          color: _purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _purple.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.collections_bookmark_outlined,
                          color: _lightPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    listTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  Icons.arrow_outward_rounded,
                                  color: Colors.white.withValues(alpha: 0.28),
                                  size: 15,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${items.length} '
                              '${items.length == 1 ? 'title' : 'titles'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildListMenu(
                        provider: provider,
                        listId: listId,
                        listTitle: listTitle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white.withValues(alpha: 0.055),
            ),
            SizedBox(
              height: 252,
              child: items.isEmpty
                  ? _buildInlineEmptyState()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 125,
                          margin: EdgeInsets.only(
                            right: index == items.length - 1 ? 0 : 14,
                          ),
                          child: _buildMovieCardFromItem(items[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListMenu({
    required WatchlistProvider provider,
    required int listId,
    required String listTitle,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'List options',
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_horiz_rounded,
          color: Colors.white.withValues(alpha: 0.62),
          size: 20,
        ),
        color: _elevatedSurface,
        surfaceTintColor: _elevatedSurface,
        elevation: 18,
        offset: const Offset(0, 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        onSelected: (value) {
          if (value == 'rename') {
            _showRenameListModal(provider, listId, listTitle);
          } else if (value == 'delete') {
            _showDeleteListConfirmation(provider, listId, listTitle);
          }
        },
        itemBuilder: (context) {
          return [
            PopupMenuItem<String>(
              value: 'rename',
              height: 46,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: _lightPurple,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Text(
                    'Rename list',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              height: 46,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: _danger,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Text(
                    'Delete list',
                    style: TextStyle(
                      color: Color(0xFFFF8A9A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }

  Widget _buildDialogHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _lightPurple.withValues(alpha: 0.18),
                _darkPurple.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _lightPurple.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: _lightPurple, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.close_rounded,
            color: Colors.white.withValues(alpha: 0.58),
            size: 21,
          ),
        ),
      ],
    );
  }

  Widget _buildListTitleField({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onSubmitted,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: _lightPurple,
      decoration: InputDecoration(
        labelText: 'List title',
        hintText: hintText,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          Icons.text_fields_rounded,
          color: Colors.white.withValues(alpha: 0.38),
          size: 19,
        ),
        filled: true,
        fillColor: const Color(0xFF0E0E12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(13),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _purple, width: 1.3),
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    );
  }

  Widget _buildModalEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _purple.withValues(alpha: 0.17)),
              ),
              child: const Icon(
                Icons.movie_filter_outlined,
                color: _lightPurple,
                size: 29,
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              'This list is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Add movies and shows to start building this collection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.022),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_to_photos_outlined,
              color: _lightPurple,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No titles yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add movies or shows from their action menu.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCardFromItem(dynamic item, {bool hideActionMenu = false}) {
    if (item is! Map) {
      return MovieCard(
        id: 0,
        title: 'Unknown',
        imageUrl: item.toString().startsWith('http')
            ? item.toString()
            : 'https://image.tmdb.org/t/p/w500${item.toString()}',
        mediaType: 'movie',
        hideActionMenu: hideActionMenu,
      );
    }

    final rawId = item['id'] ?? item['movie_id'] ?? item['media_id'];

    final int id = rawId != null ? int.tryParse(rawId.toString()) ?? 0 : 0;

    final String title =
        item['title'] ?? item['name'] ?? item['movie_title'] ?? 'Unknown';

    final String rawType = (item['media_type'] ?? '').toString().toLowerCase();

    final String mediaType =
        rawType == 'tv' || rawType == 'show' || item['name'] != null
        ? 'tv'
        : 'movie';

    final String posterPath = item['poster_path'] ?? item['poster'] ?? '';

    final String imageUrl = posterPath.isNotEmpty
        ? (posterPath.startsWith('http')
              ? posterPath
              : 'https://image.tmdb.org/t/p/w500$posterPath')
        : '';

    final releaseDate =
        (item['release_year'] ??
                item['release_date'] ??
                item['first_air_date'] ??
                item['year'] ??
                '')
            .toString();

    final yearStr = releaseDate.length >= 4
        ? releaseDate.substring(0, 4)
        : null;

    final voteAverage =
        double.tryParse(
          (item['vote_average'] ?? item['rating'] ?? 0.0).toString(),
        ) ??
        0.0;

    return MovieCard(
      id: id,
      title: title,
      imageUrl: imageUrl,
      mediaType: mediaType,
      isLandscape: false,
      year: yearStr,
      rating: voteAverage,
      hideActionMenu: hideActionMenu,
    );
  }

  Widget _buildEmptyState(String message, {required VoidCallback onCreate}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 38),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _lightPurple.withValues(alpha: 0.17),
                      _darkPurple.withValues(alpha: 0.07),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: _purple.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  color: _lightPurple,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create your first list',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.44),
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 23),
              FilledButton.icon(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text(
                  'Create new list',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SnackBar _buildSnackBar(String message, {bool isError = false}) {
    return SnackBar(
      content: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isError
                  ? _danger.withValues(alpha: 0.12)
                  : _purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? _danger : _lightPurple,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isError ? const Color(0xFF241418) : _surface,
      behavior: SnackBarBehavior.floating,
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isError
              ? const Color(0xFF57303D)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

class _ListsBackground extends StatelessWidget {
  const _ListsBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const ColoredBox(color: Color(0xFF08080B), child: SizedBox.expand()),
          Positioned(
            top: -190,
            right: -170,
            child: Container(
              width: 430,
              height: 430,
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
            bottom: -250,
            left: -190,
            child: Container(
              width: 490,
              height: 490,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8431D9).withValues(alpha: 0.07),
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
