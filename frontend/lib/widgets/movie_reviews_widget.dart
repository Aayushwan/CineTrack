import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class MovieReviewsWidget extends StatefulWidget {
  final int movieId;

  const MovieReviewsWidget({super.key, required this.movieId});

  @override
  State<MovieReviewsWidget> createState() => _MovieReviewsWidgetState();
}

class _MovieReviewsWidgetState extends State<MovieReviewsWidget> {
  final TextEditingController _commentController = TextEditingController();
  
  double _selectedRating = 5.0;
  bool _isSubmitting = false;
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _loadReviews();
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
        const SnackBar(content: Text('Please log in to leave a review')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

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
        _loadReviews(); // Refresh review list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review submitted successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting review: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Reviews & Ratings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),

        // --- Add Review Form ---
        Card(
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Write a Review',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),

                // Star Rating Selector
                Row(
                  children: [
                    const Text('Rating: ', style: TextStyle(color: Colors.white70)),
                    Row(
                      children: List.generate(5, (index) {
                        final starValue = index + 1.0;
                        return IconButton(
                          icon: Icon(
                            index < _selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setState(() => _selectedRating = starValue);
                          },
                        );
                      }),
                    ),
                    Text('${_selectedRating.toInt()}/5',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),

                // Comment Input
                TextField(
                  controller: _commentController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Share your thoughts about this movie...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Submit Button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                    ),
                    onPressed: _isSubmitting ? null : _submitReview,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    label: const Text('Post Review', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- Reviews List ---
        FutureBuilder<List<Review>>(
          future: _reviewsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)));
            } else if (snapshot.hasError) {
              return Text('Error loading reviews: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No reviews yet. Be the first to review!', style: TextStyle(color: Colors.white54)),
              );
            }

            final reviews = snapshot.data!;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final review = reviews[index];
                return ListTile(
                  tileColor: Colors.grey[850],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        review.username,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text('${review.rating.toInt()}/5', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      review.comment ?? 'No written comment',
                      style: TextStyle(
                        color: review.comment == null ? Colors.white38 : Colors.white70,
                        fontStyle: review.comment == null ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}