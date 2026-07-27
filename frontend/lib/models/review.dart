class Review {
  final int id;
  final int userId;
  final String username;
  final int movieId;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.username,
    required this.movieId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      userId: json['user_id'],
      username: json['username'],
      movieId: json['movie_id'],
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}