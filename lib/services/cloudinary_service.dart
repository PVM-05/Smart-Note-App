// lib/services/cloudinary_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer; // ✅ Thay print() bằng developer.log()
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static final String _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static final String _uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  static final String _apiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static final String _apiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  static final String _baseUrl = 'https://api.cloudinary.com/v1_1/$_cloudName';

  final ImagePicker _picker = ImagePicker();

  // ════════════════════════════════════════
  // EXTRACT PUBLIC ID
  // ════════════════════════════════════════
  String? _extractPublicId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final rootIndex = segments.indexOf('smart_note');

      if (rootIndex == -1) return null;

      String publicId = segments.sublist(rootIndex).join('/');

      // Loại bỏ phần mở rộng tệp (.jpg, .m4a, .png)
      if (publicId.contains('.')) {
        publicId = publicId.substring(0, publicId.lastIndexOf('.'));
      }

      return publicId;
    } catch (e, stackTrace) {
      developer.log(
        'Lỗi trích xuất public_id từ URL',
        error: e,
        stackTrace: stackTrace,
        name: 'app.services.cloudinary',
      );
      return null;
    }
  }

  // ════════════════════════════════════════
  // 🌟 DELETE FILE REALTIME
  // ════════════════════════════════════════
  Future<bool> deleteFile(String fileUrl, {String resourceType = 'image'}) async {
    final publicId = _extractPublicId(fileUrl);

    if (publicId == null) {
      developer.log(
        'Không tìm thấy public_id hợp lệ từ URL: $fileUrl',
        name: 'app.services.cloudinary',
        level: 900, // Cảnh báo mức độ Warning
      );
      return false;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Chuỗi cần băm sắp xếp theo bảng chữ cái alphabet (p đứng trước t)
      final stringToSign = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';

      // Tạo chuỗi băm bảo mật SHA-1
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();

      final response = await http.post(
        Uri.parse('$_baseUrl/$resourceType/destroy'),
        body: {
          'public_id': publicId,
          'api_key': _apiKey,
          'timestamp': timestamp.toString(),
          'signature': signature,
          'resource_type': resourceType,
        },
      );

      developer.log(
        'Yêu cầu xóa file Cloudinary hoàn tất',
        name: 'app.services.cloudinary',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'ok') {
          developer.log('✅ Đã xóa file thành công trên Cloudinary: $publicId', name: 'app.services.cloudinary');
          return true;
        } else if (data['result'] == 'not_found') {
          developer.log('⚠️ Không tìm thấy file trên Cloudinary (Bỏ qua cập nhật UI)', name: 'app.services.cloudinary');
          return true;
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Lỗi xảy ra trong quá trình xóa file',
        error: e,
        stackTrace: stackTrace,
        name: 'app.services.cloudinary',
      );
    }

    return false;
  }

  // ════════════════════════════════════════
  // UPLOAD IMAGE (Multipart Stream)
  // ════════════════════════════════════════
  Future<String?> uploadImage(File file, String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/image/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smart_note/$userId/images';

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        return data['secure_url'];
      } else {
        developer.log(
          'Upload ảnh thất bại từ Cloudinary API. Mã trạng thái: ${response.statusCode}',
          name: 'app.services.cloudinary',
          level: 1000,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Lỗi xảy ra trong quá trình upload ảnh',
        error: e,
        stackTrace: stackTrace,
        name: 'app.services.cloudinary',
      );
    }
    return null;
  }

  // ════════════════════════════════════════
  // UPLOAD AUDIO (Multipart Stream)
  // ════════════════════════════════════════
  Future<String?> uploadAudio(File file, String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/video/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smart_note/$userId/audio';
      request.fields['resource_type'] = 'auto';

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        return data['secure_url'];
      }
    } catch (e, stackTrace) {
      developer.log(
        'Lỗi xảy ra trong quá trình upload file âm thanh',
        error: e,
        stackTrace: stackTrace,
        name: 'app.services.cloudinary',
      );
    }
    return null;
  }

  // ════════════════════════════════════════
  // PICK IMAGE FROM GALLERY (ĐÃ TỐI ƯU HÓA UX/DUNG LƯỢNG)
  // ════════════════════════════════════════
  Future<String?> pickAndUploadImage(String userId) async {
    try {
      // 🌟 TỐI ƯU: Khống chế kích thước tối đa giúp ảnh luôn nhẹ hơn 1MB, tiết kiệm băng thông 3G/4G
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (picked == null) return null;

      return await uploadImage(File(picked.path), userId);
    } catch (e) {
      developer.log('Lỗi chọn ảnh từ thư viện', error: e, name: 'app.services.cloudinary');
      return null;
    }
  }

  // ════════════════════════════════════════
  // CAMERA IMAGE (ĐÃ TỐI ƯU HÓA UX/DUNG LƯỢNG)
  // ════════════════════════════════════════
  Future<String?> cameraAndUploadImage(String userId) async {
    try {
      // 🌟 TỐI ƯU: Khống chế kích thước tối đa khi chụp từ Camera thiết bị thật
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (picked == null) return null;

      return await uploadImage(File(picked.path), userId);
    } catch (e) {
      developer.log('Lỗi chụp ảnh từ Camera', error: e, name: 'app.services.cloudinary');
      return null;
    }
  }
}