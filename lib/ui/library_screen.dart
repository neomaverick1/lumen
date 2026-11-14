import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../data/library.dart';
import 'editor_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.library});
  final Library library;

  Future<void> _import(BuildContext context) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final p = Photo(id: 'u${DateTime.now().millisecondsSinceEpoch}', title: picked.name, bytes: bytes);
    library.add(p);
    if (context.mounted) _open(context, p);
  }

  void _open(BuildContext context, Photo p) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EditorScreen(photo: p, library: library),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final list = library.visible;
        final wide = MediaQuery.sizeOf(context).width > 700;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('import'),
            onPressed: () => _import(context),
            backgroundColor: amber,
            foregroundColor: ink,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Import', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            gradient: const LinearGradient(colors: [amber, coral]),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: ink),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lumen',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: cream,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              Text('On-device AI photo studio', style: TextStyle(color: muted, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                    child: TextField(
                      key: const Key('search'),
                      onChanged: library.search,
                      style: const TextStyle(color: cream),
                      decoration: const InputDecoration(
                        hintText: 'Smart search: cat, food, text…',
                        prefixIcon: Icon(Icons.search_rounded, color: muted),
                      ),
                    ),
                  ),
                ),
                if (library.allTags.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        children: [
                          for (final t in library.allTags)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ActionChip(label: Text('#${t.toLowerCase()}'), onPressed: () => library.search(t)),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (!library.ai.available)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: line),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.phone_iphone_rounded, color: amber, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Editing works here. Auto-tags, text scan and object detection run on-device in the Android and iPhone apps.',
                              style: TextStyle(color: muted, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  sliver: SliverGrid.builder(
                    itemCount: list.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: wide ? 4 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemBuilder: (_, i) =>
                        _PhotoCard(photo: list[i], aiOn: library.ai.available, onTap: () => _open(context, list[i])),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo, required this.onTap, required this.aiOn});
  final Photo photo;
  final bool aiOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('photo_${photo.id}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(photo.bytes, fit: BoxFit.cover, gaplessPlayback: true),
                if (photo.edited)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: amber, borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        'Edited',
                        style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: cream, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: 20,
                  child: photo.tags.isEmpty
                      ? Text(
                          photo.analyzed ? 'No tags' : (aiOn ? 'Tagging…' : 'Tap to edit'),
                          style: const TextStyle(color: muted, fontSize: 11),
                        )
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final t in photo.tags.take(3))
                              Container(
                                margin: const EdgeInsets.only(right: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: amber.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  t.label,
                                  style: const TextStyle(color: amber, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
