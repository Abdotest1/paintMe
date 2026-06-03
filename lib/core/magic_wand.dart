import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> executeMagicWand({
  required ui.Image canvasImage,
  required Offset tapPosition,
}) async {
  ByteData? byteData = await canvasImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return null;

  final int width = canvasImage.width;
  final int height = canvasImage.height;
  final Uint8List pixels = byteData.buffer.asUint8List();

  final int startX = tapPosition.dx.toInt().clamp(0, width - 1);
  final int startY = tapPosition.dy.toInt().clamp(0, height - 1);
  final int startIndex = (startY * width + startX) * 4;

  final int startR = pixels[startIndex];
  final int startG = pixels[startIndex + 1];
  final int startB = pixels[startIndex + 2];
  final int startA = pixels[startIndex + 3];

  final Uint8List visited = Uint8List(width * height);

  final List<int> queue = [];
  queue.add(startY * width + startX);
  visited[startY * width + startX] = 1;

  int minX = startX, maxX = startX;
  int minY = startY, maxY = startY;

  const int threshold = 40; // Balanced threshold

  int head = 0;
  while (head < queue.length) {
    int pos = queue[head++];
    int x = pos % width;
    int y = pos ~/ width;

    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;

    // Check 4-connectivity
    void check(int nx, int ny) {
      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        int nPos = ny * width + nx;
        if (visited[nPos] == 0) {
          int nIdx = nPos * 4;
          int dr = (pixels[nIdx] - startR).abs();
          int dg = (pixels[nIdx + 1] - startG).abs();
          int db = (pixels[nIdx + 2] - startB).abs();
          int da = (pixels[nIdx + 3] - startA).abs();

          if (dr <= threshold && dg <= threshold && db <= threshold && da <= threshold) {
            visited[nPos] = 1;
            queue.add(nPos);
          }
        }
      }
    }

    check(x + 1, y);
    check(x - 1, y);
    check(x, y + 1);
    check(x, y - 1);
  }

  if (queue.isEmpty) return null;

  return {
    'rect': Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX.toDouble() + 1, maxY.toDouble() + 1),
    'points': queue.map((pos) => Offset((pos % width).toDouble(), (pos ~/ width).toDouble())).toList(),
  };
}