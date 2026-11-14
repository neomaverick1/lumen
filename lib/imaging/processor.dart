import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'adjust.dart';

class Decoded {
  const Decoded(this.rgb, this.width, this.height);
  final Uint8List rgb;
  final int width;
  final int height;
}

Decoded decodeRgb(Uint8List bytes, {int maxSide = 1400}) {
  var image = img.decodeImage(bytes)!;
  image = img.bakeOrientation(image);
  if (image.width > maxSide || image.height > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
  }
  final rgb = Uint8List.fromList(image.getBytes(order: img.ChannelOrder.rgb));
  return Decoded(rgb, image.width, image.height);
}

Uint8List encodeJpg(Decoded d, {int quality = 92}) {
  final image = img.Image.fromBytes(width: d.width, height: d.height, bytes: d.rgb.buffer, numChannels: 3);
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

class _RenderJob {
  const _RenderJob(this.source, this.adjustments, this.crop, this.quality);
  final Decoded source;
  final Adjustments adjustments;
  final ({double left, double top, double width, double height})? crop;
  final int quality;
}

Uint8List _render(_RenderJob job) {
  var d = Decoded(Uint8List.fromList(job.source.rgb), job.source.width, job.source.height);
  if (job.crop != null) {
    final c = job.crop!;
    final image = img.Image.fromBytes(width: d.width, height: d.height, bytes: d.rgb.buffer, numChannels: 3);
    final cropped = img.copyCrop(
      image,
      x: c.left.round(),
      y: c.top.round(),
      width: c.width.round(),
      height: c.height.round(),
    );
    d = Decoded(Uint8List.fromList(cropped.getBytes(order: img.ChannelOrder.rgb)), cropped.width, cropped.height);
  }
  applyAdjustments(d.rgb, d.width, d.height, job.adjustments);
  return encodeJpg(d, quality: job.quality);
}

/// Renders off the UI thread (a background isolate on phones).
Future<Uint8List> render(
  Decoded source,
  Adjustments a, {
  ({double left, double top, double width, double height})? crop,
  int quality = 90,
}) => compute(_render, _RenderJob(source, a, crop, quality));

Future<Decoded> decodeInBackground(Uint8List bytes, {int maxSide = 1400}) =>
    compute((Uint8List b) => decodeRgb(b, maxSide: maxSide), bytes);

Future<EnhanceReport> analyzeInBackground(Decoded d) =>
    compute((Decoded x) => analyzeForEnhance(x.rgb, x.width, x.height), d);
