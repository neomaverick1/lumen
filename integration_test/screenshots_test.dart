import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumen/ai/ai.dart';
import 'package:lumen/data/library.dart';
import 'package:lumen/main.dart';
import 'package:material_ui/material_ui.dart';

/// Runs on a real Android emulator in CI with the real ML Kit models: checks the AI features
/// end to end and captures the README screenshots.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int seconds = 2]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  var converted = false;
  Future<void> shot(WidgetTester t, String name) async {
    if (!converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
    }
    await t.pump();
    await binding.takeScreenshot(name);
    await t.pump();
  }

  Future<void> back(WidgetTester t) async {
    await t.pageBack();
    await settle(t);
  }

  testWidgets('on-device AI end to end', (t) async {
    final library = Library(createAiEngine());
    await t.pumpWidget(LumenApp(library: library));
    await library.load();
    await settle(t, 4);

    // ML Kit labelled the sample photos on the device.
    expect(library.photos.firstWhere((p) => p.id == 'cat').tags.map((x) => x.label.toLowerCase()), contains('cat'));
    await shot(t, '01_library');

    // Smart search by AI tag.
    await t.enterText(find.byKey(const Key('search')), 'cat');
    await settle(t, 1);
    expect(find.byKey(const Key('photo_cat')), findsOneWidget);
    await t.enterText(find.byKey(const Key('search')), '');
    await settle(t, 1);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 1);

    // Smart Enhance + before/after.
    await t.tap(find.byKey(const Key('photo_coffee')));
    await settle(t, 3);
    await t.tap(find.byKey(const Key('smartEnhance')));
    await settle(t, 4);
    final view = find.byType(GestureDetector).first;
    final box = t.getRect(view);
    await t.tapAt(Offset(box.left + box.width * 0.5, box.center.dy));
    await settle(t, 1);
    await shot(t, '02_enhance_compare');

    // Looks.
    await t.tap(find.byKey(const Key('tab_Looks')));
    await settle(t, 4);
    await t.tap(find.byKey(const Key('look_Golden')));
    await settle(t, 3);
    await shot(t, '03_looks');

    // Adjust sliders.
    await t.tap(find.byKey(const Key('tab_Adjust')));
    await settle(t, 1);
    await shot(t, '04_adjust');

    // Auto-tags on the photo.
    await t.tap(find.byKey(const Key('tab_AI')));
    await settle(t, 1);
    await t.tap(find.byKey(const Key('ai_tags')));
    await settle(t, 4);
    await shot(t, '05_tags');
    await back(t);

    // Text scan on the menu.
    await t.tap(find.byKey(const Key('photo_menu')));
    await settle(t, 3);
    await t.tap(find.byKey(const Key('tab_AI')));
    await settle(t, 1);
    await t.tap(find.byKey(const Key('ai_text')));
    await settle(t, 5);
    expect(find.textContaining('HARBOR', findRichText: true), findsWidgets);
    await shot(t, '06_text_scan');
    await back(t);

    // Objects + smart crop on the cat.
    await t.tap(find.byKey(const Key('photo_cat')));
    await settle(t, 3);
    await t.tap(find.byKey(const Key('tab_AI')));
    await settle(t, 1);
    await t.tap(find.byKey(const Key('ai_objects')));
    await settle(t, 5);
    await shot(t, '07_objects');
    final crop = find.text('Smart crop');
    if (crop.evaluate().isNotEmpty) {
      await t.tap(crop.first);
      await settle(t, 4);
      await shot(t, '08_smart_crop');
    }
  });
}
