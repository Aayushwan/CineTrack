// frontend/lib/widgets/movie_reviews_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class MovieReviewsWidget extends StatefulWidget {
  final int movieId;

  const MovieReviewsWidget({super.key, required this.movieId});

  @override
  State<MovieReviewsWidget> createState() {
    return _MovieReviewsWidgetState();
  }
}

class _MovieReviewsWidgetState extends State<MovieReviewsWidget> {
  static const Color _surface = Color(0xFF141419);
  static const Color _elevatedSurface = Color(0xFF1A191F);
  static const Color _inputSurface = Color(0xFF0E0E12);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);
  static const Color _starColor = Color(0xFFFFB800);
  static const Color _danger = Color(0xFFFF647C);

  final TextEditingController _commentController = TextEditingController();

  double _selectedRating = 5.0;
  bool _isSubmitting = false;
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _loadReviews() {
    setState(() {
      _reviewsFuture = ApiService.getMovieReviews(widget.movieId);
    });
  }

  Future<void> _submitReview() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Please log in to leave a review', isError: true),
      );

      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await ApiService.postReview(
        movieId: widget.movieId,
        rating: _selectedRating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (success) {
        _commentController.clear();
        _loadReviews();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(_buildSnackBar('Review submitted successfully'));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Error submitting review: $e', isError: true),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: 16),
        _buildReviewForm(),
        const SizedBox(height: 24),
        FutureBuilder<List<Review>>(
          future: _reviewsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final reviews = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewsHeader(reviews.length),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reviews.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (context, index) {
                    return _buildReviewCard(
                      review: reviews[index],
                      index: index,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_lightPurple, _darkPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.24),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.rate_review_outlined,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reviews & Ratings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'See what the CineTrack community thinks',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF19131F), Color(0xFF141419)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _purple.withValues(alpha: 0.15)),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: _lightPurple,
                  size: 17,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Write a review',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Share your rating and thoughts',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;

                final label = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR RATING',
                      style: TextStyle(
                        color: _lightPurple,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedRating.toInt()} out of 5',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );

                final stars = _buildRatingSelector();

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, const SizedBox(height: 11), stars],
                  );
                }

                return Row(children: [label, const Spacer(), stars]);
              },
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentController,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
            ),
            cursorColor: _lightPurple,
            decoration: InputDecoration(
              hintText: 'Share your thoughts about this movie...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12,
              ),
              filled: true,
              fillColor: _inputSurface,
              counterStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 9,
              ),
              contentPadding: const EdgeInsets.all(15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.075),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _purple, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitReview,
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                disabledBackgroundColor: _purple.withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
              label: Text(
                _isSubmitting ? 'Posting...' : 'Post review',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        final selected = index < _selectedRating;

        return Padding(
          padding: EdgeInsets.only(right: index == 4 ? 0 : 3),
          child: Tooltip(
            message: '$starValue out of 5',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedRating = starValue;
                  });
                },
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? _starColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: selected
                          ? _starColor.withValues(alpha: 0.16)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: selected
                        ? _starColor
                        : Colors.white.withValues(alpha: 0.28),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildReviewsHeader(int reviewCount) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _purple.withValues(alpha: 0.14)),
          ),
          child: const Icon(
            Icons.forum_outlined,
            color: _lightPurple,
            size: 15,
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'Community reviews',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$reviewCount',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard({required Review review, required int index}) {
    final initial = review.username.trim().isNotEmpty
        ? review.username.trim()[0].toUpperCase()
        : '?';

    final hasComment =
        review.comment != null && review.comment!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _elevatedSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _lightPurple.withValues(alpha: 0.2),
                  _darkPurple.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: _purple.withValues(alpha: 0.2)),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: _lightPurple,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _starColor.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _starColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: _starColor,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${review.rating.toInt()}/5',
                            style: const TextStyle(
                              color: Color(0xFFFFD76A),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasComment ? review.comment! : 'No written comment',
                  style: TextStyle(
                    color: hasComment
                        ? Colors.white.withValues(alpha: 0.66)
                        : Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                    height: 1.5,
                    fontStyle: hasComment ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 35),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: _lightPurple,
            strokeWidth: 2.4,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF241418).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _danger.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _danger,
              size: 24,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Unable to load reviews',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Error loading reviews: $error',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: _loadReviews,
            style: OutlinedButton.styleFrom(
              foregroundColor: _danger,
              side: BorderSide(color: _danger.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Try again',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.09),
              shape: BoxShape.circle,
              border: Border.all(color: _purple.withValues(alpha: 0.15)),
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              color: _lightPurple,
              size: 27,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'No reviews yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first person to share a review.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
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
