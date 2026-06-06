class PromoItem {
  final String title;
  final String description;
  final String img;
  final String url;

  PromoItem({
    required this.title,
    required this.description,
    required this.img,
    required this.url,
  });

  factory PromoItem.fromJson(Map<String, dynamic> json) {
    return PromoItem(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      img: json['img'] ?? '',
      url: json['url'] ?? '',
    );
  }

  String get fullImgUrl {
    if (img.startsWith('http')) {
      return img;
    }
    return 'https://www.moely.link${img.startsWith('/') ? '' : '/'}$img';
  }
}
