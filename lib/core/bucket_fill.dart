import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<ui.Image?> executeBucketFill({
  required ui.Image canvasImage,
  required Offset tapPosition,
  required Color selectedColor,
}) async {
  ByteData? byteData = await canvasImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) throw Exception("Failed to read canvas");

  final int width = canvasImage.width;
  final int height = canvasImage.height;

  final Uint8List samplePixels = Uint8List.fromList(byteData.buffer.asUint8List());
  final Uint8List outputPixels = Uint8List(width * height * 4);
  final Uint8List visited = Uint8List(width * height);

  final int startX = tapPosition.dx.toInt().clamp(0, width - 1);
  final int startY = tapPosition.dy.toInt().clamp(0, height - 1);
  final int startIndex = (startY * width + startX) * 4;

  int startR = samplePixels[startIndex];
  int startG = samplePixels[startIndex + 1];
  int startB = samplePixels[startIndex + 2];
  int startA = samplePixels[startIndex + 3];

  int fillR = selectedColor.red;
  int fillG = selectedColor.green;
  int fillB = selectedColor.blue;
  int fillA = selectedColor.alpha;

  // --- THE FIX: Tighter Tolerance ---
  // Lowered from 100 to 30 to prevent the fill algorithm from
  // leaking through the anti-aliased corners of mathematical shapes.
  int threshold = 30;

  bool colorMatch(int i) {
    return (samplePixels[i] - startR).abs() <= threshold &&
        (samplePixels[i + 1] - startG).abs() <= threshold &&
        (samplePixels[i + 2] - startB).abs() <= threshold &&
        (samplePixels[i + 3] - startA).abs() <= threshold;
  }

  void setPixel(int idx) {
    outputPixels[idx] = fillR;
    outputPixels[idx + 1] = fillG;
    outputPixels[idx + 2] = fillB;
    outputPixels[idx + 3] = fillA;
    visited[idx ~/ 4] = 1;
  }

  Int32List queueX = Int32List(width * height);
  Int32List queueY = Int32List(width * height);
  int head = 0;
  int tail = 0;

  setPixel(startIndex);
  queueX[tail] = startX;
  queueY[tail] = startY;
  tail++;

  while (head < tail) {
    int cx = queueX[head];
    int cy = queueY[head];
    head++;

    int idx = (cy * width + cx) * 4;

    if (cx > 0) {
      int nIdx = idx - 4;
      if (visited[nIdx ~/ 4] == 0 && colorMatch(nIdx)) {
        setPixel(nIdx);
        queueX[tail] = cx - 1; queueY[tail] = cy; tail++;
      }
    }
    if (cx < width - 1) {
      int nIdx = idx + 4;
      if (visited[nIdx ~/ 4] == 0 && colorMatch(nIdx)) {
        setPixel(nIdx);
        queueX[tail] = cx + 1; queueY[tail] = cy; tail++;
      }
    }
    if (cy > 0) {
      int nIdx = idx - (width * 4);
      if (visited[nIdx ~/ 4] == 0 && colorMatch(nIdx)) {
        setPixel(nIdx);
        queueX[tail] = cx; queueY[tail] = cy - 1; tail++;
      }
    }
    if (cy < height - 1) {
      int nIdx = idx + (width * 4);
      if (visited[nIdx ~/ 4] == 0 && colorMatch(nIdx)) {
        setPixel(nIdx);
        queueX[tail] = cx; queueY[tail] = cy + 1; tail++;
      }
    }
  }

  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromPixels(
    outputPixels, width, height, ui.PixelFormat.rgba8888,
        (img) => completer.complete(img),
  );

  return await completer.future;
}