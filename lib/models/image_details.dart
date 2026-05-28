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
}
