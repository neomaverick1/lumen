import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/ai/ai_engine.dart';
import 'package:lumen/data/library.dart';
import 'package:lumen/main.dart';
import 'package:material_ui/material_ui.dart';

class FakeAi implements AiEngine {
  @override
  bool get available => true;
  @override
  String get name => 'fake';
  @override
  Future<List<Tag>> tags(String imagePath) async => imagePath.contains('cat')
      ? const [Tag('Cat', 0.94), Tag('Whiskers', 0.81)]
      : imagePath.contains('coffee')
      ? const [Tag('Cup', 0.9), Tag('Food', 0.7)]
      : const [Tag('Sky', 0.7)];
  @override
  Future<List<TextLine>> readText(String imagePath) async => const [];
  @override
  Future<List<FoundObject>> objects(String imagePath) async => const [];
  @override
  void dispose() {}
}

void main() {
  testWidgets('library loads samples, tags them and searches by tag', (t) async {
    final lib = Library(FakeAi(), tempWriter: (name, _) async => name);
    await t.runAsync(lib.load);
    await t.pumpWidget(LumenApp(library: lib));
    await t.pumpAndSettle();

    expect(lib.photos, hasLength(5));
    expect(lib.photos.firstWhere((p) => p.id == 'cat').tags.first.label, 'Cat');
    expect(find.text('Lumen'), findsOneWidget);

    lib.search('whisk');
    await t.pumpAndSettle();
    expect(lib.visible.map((p) => p.id), ['cat']);
    expect(find.byKey(const Key('photo_cat')), findsOneWidget);
    expect(find.byKey(const Key('photo_coffee')), findsNothing);

    lib.search('cafe');
    expect(lib.visible.map((p) => p.id), ['menu']);
    lib.search('');
    expect(lib.visible, hasLength(5));
    expect(lib.allTags, containsAll(['Cat', 'Cup']));
  });
}
