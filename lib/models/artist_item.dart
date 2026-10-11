import 'image_item.dart';

class ArtistItem {
  final String uid;
  final String name;
  final String avatar;
  final int count;
  final bool hasPixiv;
  final bool hasTwitter;
  final String platform; // 'both', 'pixiv', 'twitter'
  final String artistUrl;

  ArtistItem({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.count,
    required this.hasPixiv,
    required this.hasTwitter,
    required this.platform,
    required this.artistUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'avatar': avatar,
      'count': count,
      'hasPixiv': hasPixiv,
      'hasTwitter': hasTwitter,
      'platform': platform,
      'artistUrl': artistUrl,
    };
  }

  factory ArtistItem.fromJson(Map<String, dynamic> json) {
    return ArtistItem(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      count: json['count'] ?? 0,
      hasPixiv: json['hasPixiv'] ?? false,
      hasTwitter: json['hasTwitter'] ?? false,
      platform: json['platform'] ?? 'pixiv',
      artistUrl: json['artistUrl'] ?? '',
    );
  }
}

class ArtistProfile {
  final String uid;
  final String name;
  final String avatar;
  final int count;
  final bool hasPixiv;
  final bool hasTwitter;
  final String? pixivUrl;
  final String? twitterUrl;
  final List<MoelyImage> images;
  final int totalPages;

  ArtistProfile({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.count,
    required this.hasPixiv,
    required this.hasTwitter,
    this.pixivUrl,
    this.twitterUrl,
    required this.images,
    required this.totalPages,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'avatar': avatar,
      'count': count,
      'hasPixiv': hasPixiv,
      'hasTwitter': hasTwitter,
      'pixivUrl': pixivUrl,
      'twitterUrl': twitterUrl,
      'images': images.map((e) => e.toJson()).toList(),
      'totalPages': totalPages,
    };
  }

  factory ArtistProfile.fromJson(Map<String, dynamic> json) {
    final list = (json['images'] as List? ?? [])
        .map((item) => MoelyImage.fromJson(item as Map<String, dynamic>))
        .toList();
    return ArtistProfile(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      count: json['count'] ?? 0,
      hasPixiv: json['hasPixiv'] ?? false,
      hasTwitter: json['hasTwitter'] ?? false,
      pixivUrl: json['pixivUrl'],
      twitterUrl: json['twitterUrl'],
      images: list,
      totalPages: json['totalPages'] ?? 1,
    );
  }
}
