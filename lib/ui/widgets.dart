import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

class OverlayBox {
  const OverlayBox(this.rect, this.label, this.color);
  final Rect rect;
  final String? label;
  final Color color;
}

/// Before/after view: the original shows left of the handle, the edit to the right.
class CompareView extends StatelessWidget {
  const CompareView({
    super.key,
    required this.before,
    required this.after,
    required this.split,
    required this.imageSize,
    this.onSplit,
    this.boxes = const [],
    this.busy = false,
  });

  final Uint8List before;
  final Uint8List after;
  final double split;
  final ValueChanged<double>? onSplit;
  final Size imageSize;
  final List<OverlayBox> boxes;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final scale = (c.maxWidth / imageSize.width) < (c.maxHeight / imageSize.height)
            ? c.maxWidth / imageSize.width
            : c.maxHeight / imageSize.height;
        final w = imageSize.width * scale, h = imageSize.height * scale;
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: GestureDetector(
              onHorizontalDragUpdate: onSplit == null
                  ? null
                  : (d) => onSplit!((d.localPosition.dx / w).clamp(0.0, 1.0)),
              onTapDown: onSplit == null ? null : (d) => onSplit!((d.localPosition.dx / w).clamp(0.0, 1.0)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(after, fit: BoxFit.fill, gaplessPlayback: true),
                    if (split < 1)
                      ClipRect(
                        clipper: _LeftClip(split),
                        child: Image.memory(before, fit: BoxFit.fill, gaplessPlayback: true),
                      ),
                    if (split < 1) ...[
                      Positioned(
                        left: w * split - 1,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 2, color: Colors.white),
                      ),
                      Positioned(
                        left: w * split - 18,
                        top: h / 2 - 18,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.compare_arrows_rounded, color: ink, size: 20),
                        ),
                      ),
                      const Positioned(left: 10, top: 10, child: _Badge('BEFORE')),
                      const Positioned(right: 10, top: 10, child: _Badge('AFTER')),
                    ],
                    for (final b in boxes)
                      Positioned(
                        left: b.rect.left * scale,
                        top: b.rect.top * scale,
                        width: b.rect.width * scale,
                        height: b.rect.height * scale,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: b.color, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.topLeft,
                          child: b.label == null
                              ? null
                              : Container(
                                  color: b.color,
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  child: Text(
                                    b.label!,
                                    style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ),
                        ),
                      ),
                    if (busy)
                      const Positioned(
                        right: 10,
                        bottom: 10,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: amber),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeftClip extends CustomClipper<Rect> {
  _LeftClip(this.f);
  final double f;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * f, size.height);
  @override
  bool shouldReclip(_LeftClip old) => old.f != f;
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
    ),
  );
}

class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 86,
        child: Text(
          label,
          style: const TextStyle(color: cream, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      Expanded(
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
      SizedBox(
        width: 36,
        child: Text(
          '${value > 0 ? '+' : ''}${(value * 100).round()}',
          textAlign: TextAlign.right,
          style: TextStyle(color: value == 0 ? muted : amber, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    ],
  );
}
