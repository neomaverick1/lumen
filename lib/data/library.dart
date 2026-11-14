import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../ai/ai.dart';
import 'files.dart';

class Photo {
  Photo({required this.id, required this.title, required this.bytes, this.asset});
  final String id;
  final String title;
  final String? asset;
  Uint8List bytes;
  List<Tag> tags = const [];
  bool analyzed = false;
  bool edited = false;
}

/// Sample photos (CC0 / public domain) plus anything the user imports.
class Library extends ChangeNotifier {
  Library(this.ai, {Future<String> Function(String name, Uint8List bytes)? tempWriter})
    : _write = tempWriter ?? writeTemp;
  final AiEngine ai;
  final Future<String> Function(String name, Uint8List bytes) _write;
  final List<Photo> photos = [];
  String query = '';
  bool loading = true;

  static const samples = {
    'cat': 'Chelsea the cat',
    'coffee': 'Morning espresso',
    'menu': 'Harbor Cafe menu',
    'rocket': 'Launch day',
    'galaxy': 'Deep field',
  };

  Future<void> load() async {
    for (final e in samples.entries) {
      final data = await rootBundle.load('assets/samples/${e.key}.jpg');
      photos.add(Photo(id: e.key, title: e.value, asset: e.key, bytes: data.buffer.asUint8List()));
    }
    loading = false;
    notifyListeners();
    if (ai.available) {
      for (final p in photos) {
        await analyze(p);
      }
    }
  }

  Future<void> analyze(Photo p) async {
    try {
      final path = await _write('${p.id}.jpg', p.bytes);
      p.tags = await ai.tags(path);
    } catch (_) {
      p.tags = const [];
    }
    p.analyzed = true;
    notifyListeners();
  }

  void add(Photo p) {
    photos.insert(0, p);
    notifyListeners();
    if (ai.available) analyze(p);
  }

  void replace(Photo p, Uint8List bytes) {
    p.bytes = bytes;
    p.edited = true;
    notifyListeners();
  }

  void search(String q) {
    query = q;
    notifyListeners();
  }

  /// Smart search: matches titles and the labels ML Kit found in each photo.
  List<Photo> get visible {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return photos;
    return photos
        .where((p) => p.title.toLowerCase().contains(q) || p.tags.any((t) => t.label.toLowerCase().contains(q)))
        .toList();
  }

  Set<String> get allTags => {for (final p in photos) ...p.tags.take(3).map((t) => t.label)};
}
