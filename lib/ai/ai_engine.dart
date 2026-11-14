import 'dart:ui';

class Tag {
  const Tag(this.label, this.confidence);
  final String label;
  final double confidence;
}

class TextLine {
  const TextLine(this.text, this.box);
  final String text;
  final Rect box;
}

class FoundObject {
  const FoundObject(this.label, this.confidence, this.box);
  final String label;
  final double confidence;
  final Rect box;
}

/// On-device AI. Phones use Google ML Kit (no network, nothing leaves the device).
abstract interface class AiEngine {
  bool get available;
  String get name;
  Future<List<Tag>> tags(String imagePath);
  Future<List<TextLine>> readText(String imagePath);
  Future<List<FoundObject>> objects(String imagePath);
  void dispose();
}
