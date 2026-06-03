import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:file_selector/file_selector.dart';

class ImageUtils {
  static Future<ui.Image?> pickImageFromGallery() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final Uint8List bytes = await pickedFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      return frameInfo.image;
    }
    return null;
  }

  static Future<void> saveCanvasToGallery({
    required GlobalKey canvasKey,
    required bool isBgVisible,
    required Color bgColor,
  }) async {
    RenderRepaintBoundary boundary = canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (isBgVisible) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Paint()..color = bgColor,
      );
    }

    canvas.drawImage(image, Offset.zero, Paint());
    final ui.Image finalImage = await recorder.endRecording().toImage(image.width, image.height);

    ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {

        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: 'ultimate_paint_${DateTime.now().millisecondsSinceEpoch}.png',
          acceptedTypeGroups: [
            const XTypeGroup(label: 'PNG Image', extensions: ['png']),
          ],
        );

        if (result != null) {
          final File file = File(result.path);
          await file.writeAsBytes(pngBytes);
        } else {
          throw Exception("Save cancelled by user.");
        }

      } else {
        await Gal.putImageBytes(pngBytes);
      }

    } else {
      throw Exception("Failed to convert canvas to bytes.");
    }
  }

  static Future<Uint8List> imageToBytes(ui.Image image) async {
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      return byteData.buffer.asUint8List();
    }
    throw Exception("Failed to convert image to bytes.");
  }

  static Future<ui.Image> bytesToImage(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  static Future<ui.Image> resizeImage(ui.Image image, int targetWidth, int targetHeight) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = ui.FilterQuality.high;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    return await picture.toImage(targetWidth, targetHeight);
  }
}