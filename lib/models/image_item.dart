class MoelyImage {
  final String id;
  final String user;
  final String category;
  final String urls;
  final String? total;

  MoelyImage({
    required this.id,
    required this.user,
    required this.category,
    required this.urls,
    this.total,
  });

  /// Dynamically strips any leading '@' symbol to avoid UI duplication
  String get cleanUser {
    if (user.startsWith('@')) {
      return user.substring(1).trim();
    }
    return user.trim();
  }

  factory MoelyImage.fromJson(Map<String, dynamic> json) {
    return MoelyImage(
      id: json['id']?.toString() ?? '',
      user: json['user']?.toString() ?? 'Unknown',
      category: json['category']?.toString() ?? 'Other',
      urls: json['urls']?.toString() ?? '',
      total: json['total']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user,
      'category': category,
      'urls': urls,
      if (total != null) 'total': total,
    };
  }
}
