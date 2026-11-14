import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' hide TextLine;

import 'ai_engine.dart';

AiEngine createAiEngine() => MlKitEngine();

class MlKitEngine implements AiEngine {
  final _labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.55));
  final _text = TextRecognizer(script: TextRecognitionScript.latin);
  final _objects = ObjectDetector(
    options: ObjectDetectorOptions(mode: DetectionMode.single, classifyObjects: true, multipleObjects: true),
  );

  @override
  bool get available => true;

  @override
  String get name => 'Google ML Kit (on-device)';

  @override
  Future<List<Tag>> tags(String imagePath) async {
    final labels = await _labeler.processImage(InputImage.fromFilePath(imagePath));
    labels.sort((a, b) => b.confidence.compareTo(a.confidence));
    return [for (final l in labels.take(8)) Tag(l.label, l.confidence)];
  }

  @override
  Future<List<TextLine>> readText(String imagePath) async {
    final r = await _text.processImage(InputImage.fromFilePath(imagePath));
    return [
      for (final b in r.blocks)
        for (final l in b.lines) TextLine(l.text, l.boundingBox),
    ];
  }

  @override
  Future<List<FoundObject>> objects(String imagePath) async {
    final r = await _objects.processImage(InputImage.fromFilePath(imagePath));
    return [
      for (final o in r)
        FoundObject(
          o.labels.isEmpty ? 'Object' : o.labels.first.text,
          o.labels.isEmpty ? 0 : o.labels.first.confidence,
          o.boundingBox,
        ),
    ];
  }

  @override
  void dispose() {
    _labeler.close();
    _text.close();
    _objects.close();
  }
}
