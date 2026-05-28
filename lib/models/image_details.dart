class ImageDetails {
  final String id;
  final String title;
  final String resolution;
  final List<String> tags;
  final String sourceUrl;
  final String downloadUrl; // First high-res download URL
  final List<String> downloadUrls; // All high-res download URLs (for multi-image)
  final List<String> previewUrls; // All medium-res preview URLs (for multi-image)
  final String description; // Description parsed from #detail_info
  String? translatedText;

  ImageDetails({
    required this.id,
    required this.title,
    required this.resolution,
    required this.tags,
    required this.sourceUrl,
    required this.downloadUrl,
    required this.downloadUrls,
    required this.previewUrls,
    required this.description,
    this.translatedText,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'resolution': resolution,
      'tags': tags,
      'sourceUrl': sourceUrl,
      'downloadUrl': downloadUrl,
      'downloadUrls': downloadUrls,
      'previewUrls': previewUrls,
      'description': description,
      'translatedText': translatedText,
    };
  }

  factory ImageDetails.fromJson(Map<String, dynamic> json) {
    return ImageDetails(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      resolution: json['resolution'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      sourceUrl: json['sourceUrl'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      downloadUrls: List<String>.from(json['downloadUrls'] ?? []),
      previewUrls: List<String>.from(json['previewUrls'] ?? []),
      description: json['description'] ?? '',
      translatedText: json['translatedText'],
    );
  }
}
