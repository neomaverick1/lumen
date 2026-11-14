import 'package:material_ui/material_ui.dart';

import 'ai/ai.dart';
import 'core/theme.dart';
import 'data/library.dart';
import 'ui/library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final library = Library(createAiEngine())..load();
  runApp(LumenApp(library: library));
}

class LumenApp extends StatelessWidget {
  const LumenApp({super.key, required this.library});
  final Library library;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lumen',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: LibraryScreen(library: library),
  );
}
