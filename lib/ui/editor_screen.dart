import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../ai/ai.dart';
import '../core/theme.dart';
import '../data/files.dart';
import '../data/library.dart';
import '../imaging/adjust.dart';
import '../imaging/processor.dart';
import 'widgets.dart';

typedef Crop = ({double left, double top, double width, double height});

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.photo, required this.library, this.initialTab = 0});
  final Photo photo;
  final Library library;
  final int initialTab;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Decoded? _source;
  Uint8List? _original;
  Uint8List? _preview;
  Adjustments _enhance = const Adjustments();
  Adjustments _manual = const Adjustments();
  String _preset = 'Original';
  Crop? _crop;
  EnhanceReport? _report;
  late int _tab = widget.initialTab;
  bool _busy = false;
  double _split = 1; // 1 = all "after"; drag to compare
  Timer? _debounce;
  final Map<String, Uint8List> _thumbs = {};

  // AI results
  List<Tag>? _tags;
  List<TextLine>? _lines;
  List<FoundObject>? _objects;
  String? _aiBusy;

  AiEngine get ai => widget.library.ai;

  Adjustments get _current => _enhance.plus(presets[_preset]!).plus(_manual);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await decodeInBackground(widget.photo.bytes);
    final original = await render(d, const Adjustments());
    if (!mounted) return;
    setState(() {
      _source = d;
      _original = original;
      _preview = original;
    });
    _makeThumbs();
  }

  Future<void> _makeThumbs() async {
    final small = await decodeInBackground(widget.photo.bytes, maxSide: 220);
    for (final name in presets.keys) {
      final t = await render(small, _enhance.plus(presets[name]!), quality: 80);
      if (!mounted) return;
      setState(() => _thumbs[name] = t);
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 90), _rerender);
  }

  Future<void> _rerender() async {
    final s = _source;
    if (s == null) return;
    setState(() => _busy = true);
    final out = await render(s, _current, crop: _crop);
    if (!mounted) return;
    setState(() {
      _preview = out;
      _busy = false;
    });
  }

  Future<void> _smartEnhance() async {
    final s = _source;
    if (s == null) return;
    setState(() => _busy = true);
    final r = await analyzeInBackground(s);
    if (!mounted) return;
    setState(() {
      _report = r;
      _enhance = r.adjustments;
    });
    HapticFeedback.mediumImpact();
    await _rerender();
    _thumbs.clear();
    _makeThumbs();
  }

  Future<String> _currentFile() => writeTemp('lumen_${widget.photo.id}_edit.jpg', _preview!);

  Future<void> _runAi(String which) async {
    if (!ai.available || _preview == null) return;
    setState(() => _aiBusy = which);
    try {
      final path = await _currentFile();
      switch (which) {
        case 'tags':
          final t = await ai.tags(path);
          setState(() => _tags = t);
        case 'text':
          final l = await ai.readText(path);
          setState(() => _lines = l);
        case 'objects':
          final o = await ai.objects(path);
          setState(() => _objects = o);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI failed: $e')));
    } finally {
      if (mounted) setState(() => _aiBusy = null);
    }
  }

  void _smartCropTo(FoundObject o) {
    final s = _source!;
    final base = _crop ?? (left: 0.0, top: 0.0, width: s.width.toDouble(), height: s.height.toDouble());
    final c = smartCrop(
      imageWidth: s.width.toDouble(),
      imageHeight: s.height.toDouble(),
      left: base.left + o.box.left,
      top: base.top + o.box.top,
      width: o.box.width,
      height: o.box.height,
      aspect: 4 / 5,
    );
    setState(() {
      _crop = c;
      _objects = null;
      _lines = null;
    });
    _rerender();
  }

  Future<void> _save() async {
    final s = _source;
    if (s == null) return;
    final full = await decodeInBackground(widget.photo.bytes, maxSide: 4096);
    final scale = full.width / s.width;
    final crop = _crop == null
        ? null
        : (
            left: _crop!.left * scale,
            top: _crop!.top * scale,
            width: _crop!.width * scale,
            height: _crop!.height * scale,
          );
    final bytes = await render(full, _current, crop: crop, quality: 94);
    widget.library.replace(widget.photo, bytes);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: 'lumen_${widget.photo.id}.jpg', mimeType: 'image/jpeg')],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.photo.title, style: const TextStyle(fontSize: 18)),
        actions: [
          if (_crop != null)
            IconButton(
              tooltip: 'Undo crop',
              onPressed: () {
                setState(() => _crop = null);
                _rerender();
              },
              icon: const Icon(Icons.crop_free_rounded),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              key: const Key('export'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: _preview == null ? null : _save,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Export'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: _preview == null
                  ? const Center(child: CircularProgressIndicator(color: amber))
                  : CompareView(
                      before: _original!,
                      after: _preview!,
                      split: _crop == null ? _split : 1,
                      onSplit: _crop == null ? (v) => setState(() => _split = v) : null,
                      imageSize: Size(
                        (_crop?.width ?? _source!.width.toDouble()),
                        (_crop?.height ?? _source!.height.toDouble()),
                      ),
                      boxes: [
                        ...?_objects?.map(
                          (o) => OverlayBox(o.box, '${o.label} ${(o.confidence * 100).round()}%', coral),
                        ),
                        ...?_lines?.map((l) => OverlayBox(l.box, null, amber)),
                      ],
                      busy: _busy,
                    ),
            ),
          ),
          SizedBox(height: 236, child: _panel()),
          _tabs(),
        ],
      ),
    );
  }

  Widget _tabs() {
    const items = [
      (Icons.auto_awesome_rounded, 'Enhance'),
      (Icons.filter_vintage_rounded, 'Looks'),
      (Icons.tune_rounded, 'Adjust'),
      (Icons.psychology_alt_rounded, 'AI'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  key: Key('tab_${items[i].$2}'),
                  onTap: () => setState(() => _tab = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Icon(items[i].$1, color: _tab == i ? amber : muted),
                        const SizedBox(height: 3),
                        Text(
                          items[i].$2,
                          style: TextStyle(color: _tab == i ? amber : muted, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _panel() {
    switch (_tab) {
      case 0:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          children: [
            FilledButton.icon(
              key: const Key('smartEnhance'),
              onPressed: _source == null ? null : _smartEnhance,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(_report == null ? 'Smart Enhance' : 'Re-run Smart Enhance'),
            ),
            const SizedBox(height: 12),
            if (_report == null)
              const Text(
                'Reads the histogram and colour balance, then fixes levels, colour cast, exposure and dull colours in one tap.',
                style: TextStyle(color: muted, height: 1.4),
              )
            else ...[
              for (final n in _report!.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(n, style: const TextStyle(color: cream)),
                      ),
                    ],
                  ),
                ),
              Text(
                'Brightness ${(_report!.meanLuma * 100).round()}% · Saturation ${(_report!.meanSaturation * 100).round()}% · drag the photo to compare',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ],
        );
      case 1:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          children: [
            for (final name in presets.keys)
              GestureDetector(
                key: Key('look_$name'),
                onTap: () {
                  setState(() => _preset = name);
                  _schedule();
                },
                child: Container(
                  width: 104,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 130,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _preset == name ? amber : Colors.transparent, width: 2.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _thumbs[name] == null
                            ? Container(color: panel2)
                            : Image.memory(_thumbs[name]!, fit: BoxFit.cover, width: 104, gaplessPlayback: true),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: TextStyle(
                          color: _preset == name ? amber : cream,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case 2:
        Widget s(String label, double v, double min, double max, Adjustments Function(double) f) => SliderRow(
          label: label,
          value: v,
          min: min,
          max: max,
          onChanged: (x) {
            setState(() => _manual = f(x));
            _schedule();
          },
        );
        final m = _manual;
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: [
            s('Exposure', m.exposure, -1, 1, (x) => m.copyWith(exposure: x)),
            s('Contrast', m.contrast, -1, 1, (x) => m.copyWith(contrast: x)),
            s('Saturation', m.saturation, -1, 1, (x) => m.copyWith(saturation: x)),
            s('Warmth', m.warmth, -1, 1, (x) => m.copyWith(warmth: x)),
            s('Highlights', m.highlights, -1, 1, (x) => m.copyWith(highlights: x)),
            s('Shadows', m.shadows, -1, 1, (x) => m.copyWith(shadows: x)),
            s('Vignette', m.vignette, 0, 1, (x) => m.copyWith(vignette: x)),
            s('Fade', m.fade, 0, 1, (x) => m.copyWith(fade: x)),
          ],
        );
      default:
        return _aiPanel();
    }
  }

  Widget _aiPanel() {
    if (!ai.available) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Auto-tags, text scan and object detection use Google ML Kit on the phone itself. Install the Android app or run the iPhone build to try them.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.4),
          ),
        ),
      );
    }
    Widget action(String key, IconData icon, String title, String sub) => Expanded(
      child: InkWell(
        key: Key('ai_$key'),
        onTap: _aiBusy == null ? () => _runAi(key) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line),
          ),
          child: Column(
            children: [
              _aiBusy == key
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: amber),
                    )
                  : Icon(icon, color: amber),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(color: cream, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        Row(
          children: [
            action('tags', Icons.sell_rounded, 'Auto-tag', 'What is in it'),
            const SizedBox(width: 8),
            action('text', Icons.document_scanner_rounded, 'Scan text', 'Copy any text'),
            const SizedBox(width: 8),
            action('objects', Icons.center_focus_strong_rounded, 'Objects', 'Smart crop'),
          ],
        ),
        const SizedBox(height: 12),
        if (_tags != null)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_tags!.isEmpty) const Text('No confident labels', style: TextStyle(color: muted)),
              for (final t in _tags!) Chip(label: Text('${t.label}  ${(t.confidence * 100).round()}%')),
            ],
          ),
        if (_lines != null) ...[
          Row(
            children: [
              Text(
                '${_lines!.length} lines found',
                style: const TextStyle(color: cream, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _lines!.map((l) => l.text).join('\n')));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text copied')));
                },
                icon: const Icon(Icons.copy_rounded, size: 16, color: amber),
                label: const Text('Copy all', style: TextStyle(color: amber)),
              ),
            ],
          ),
          Text(_lines!.map((l) => l.text).join('\n'), style: const TextStyle(color: muted, height: 1.4)),
        ],
        if (_objects != null) ...[
          if (_objects!.isEmpty) const Text('No objects found', style: TextStyle(color: muted)),
          for (final o in _objects!)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.crop_portrait_rounded, color: coral),
              title: Text(
                o.label,
                style: const TextStyle(color: cream, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${(o.confidence * 100).round()}% · ${o.box.width.round()}×${o.box.height.round()} px',
                style: const TextStyle(color: muted),
              ),
              trailing: TextButton(
                onPressed: () => _smartCropTo(o),
                child: const Text('Smart crop', style: TextStyle(color: amber)),
              ),
            ),
        ],
      ],
    );
  }
}
