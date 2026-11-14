import 'ai_engine.dart';

AiEngine createAiEngine() => UnavailableEngine();

/// ML Kit runs on Android and iOS only. The web build keeps every editing tool and
/// explains where the AI tools run.
class UnavailableEngine implements AiEngine {
  @override
  bool get available => false;
  @override
  String get name => 'Available in the Android and iPhone apps';
  @override
  Future<List<Tag>> tags(String imagePath) async => const [];
  @override
  Future<List<TextLine>> readText(String imagePath) async => const [];
  @override
  Future<List<FoundObject>> objects(String imagePath) async => const [];
  @override
  void dispose() {}
}
