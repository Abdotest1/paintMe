import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';

class AiImageService {
  // --- Remove.bg Config ---
  static const String _removeBgKey = "BmRonAHhxZXgzHUjRftcuT8v";
  static const String _removeBgUrl = "https://api.remove.bg/v1.0/removebg";

  /// Removes the background using remove.bg
  static Future<Uint8List?> removeBackground(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_removeBgUrl))
        ..headers['X-Api-Key'] = _removeBgKey
        ..files.add(http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: 'image.png',
          contentType: MediaType('image', 'png'),
        ))
        ..fields['size'] = 'auto';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print("RemoveBG Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Exception in removeBackground: $e");
      return null;
    }
  }

  static Future<String?> uploadToCloudinary(
      Uint8List imageBytes,
      ) async {

    try {

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://api.cloudinary.com/v1_1/dkps5eoe3/image/upload',
        ),
      );

      request.fields['upload_preset'] =
      'flutter_upload';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'image.png',
        ),
      );

      final response = await request.send();

      final responseData = await response.stream.bytesToString();

      print(responseData);

      final data = jsonDecode(responseData);

      return data['secure_url'];

    } catch (e) {

      print(e);

      return null;
    }
  }

  // =========================
  // CLOUDINARY AI REMOVE
  // =========================

  static String generateRemoveUrl(
      String imageUrl,
      ) {

    return imageUrl.replaceFirst(
      '/upload/',
      '/upload/e_gen_remove:prompt_person/',
    );
  }

  static const String stabilityKey =
      "sk-u5SIvkxYCHROJ9JkFlD4M3OZv4klZ71lQ75gtPatA4eWV9MC";

  static Future<Uint8List?> eraseWithStability({
    required Uint8List imageBytes,
    required Uint8List maskBytes,
  }) async {

    try {

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://api.stability.ai/v2beta/stable-image/edit/erase',
        ),
      );

      request.headers['Authorization'] =
      'Bearer $stabilityKey';

      request.headers['Accept'] = 'image/*';

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'image.png',
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'mask',
          maskBytes,
          filename: 'mask.png',
        ),
      );

      request.fields['output_format'] = 'png';

      final response = await request.send();

      if (response.statusCode == 200) {

        return await response.stream.toBytes();

      } else {

        final error =
        await response.stream.bytesToString();

        print(error);

        return null;
      }

    } catch (e) {

      print(e);

      return null;
    }
  }
}