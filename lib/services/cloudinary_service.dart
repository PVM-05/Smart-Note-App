// lib/services/cloudinary_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  // 🔑 Dùng getter thay vì static final field
  // Lý do: static final được khởi tạo ngay khi class load (có thể trước dotenv.load())
  // Getter đảm bảo giá trị được đọc SAU KHI dotenv.load() trong main() hoàn thành
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  static String get _apiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get _apiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  static String get _baseUrl => 'https://api.cloudinary.com/v1_1/$_cloudName';

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
    } catch (e) {
      developer.log('❌ extract public_id error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════
  // 🌟 DELETE FILE REALTIME (ĐÃ FIX LỖI SIGNATURE)
  // ════════════════════════════════════════
  Future<bool> deleteFile(String fileUrl, {String resourceType = 'image'}) async {
    final publicId = _extractPublicId(fileUrl);

    if (publicId == null) {
      developer.log('❌ Không tìm thấy public_id hợp lệ từ URL: $fileUrl');
      return false;
    }

    try {
      // Lấy thời gian UTC timestamp chuẩn giây
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 🌟 Sửa lỗi cấu trúc chữ ký:
      // Chuỗi cần băm phải sắp xếp các cặp key=value theo alphabet (p đứng trước t)
      // Nối trực tiếp _apiSecret vào cuối chuỗi
      final stringToSign = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';

      // Tạo chuỗi băm bảo mật SHA-1
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();

      // Gửi yêu cầu tới đúng endpoint theo cấu trúc dạng: /image/destroy hoặc /video/destroy
      final response = await http.post(
        Uri.parse('$_baseUrl/$resourceType/destroy'),
        body: {
          'public_id': publicId,
          'api_key': _apiKey,
          'timestamp': timestamp.toString(),
          'signature': signature,
          // 🌟 BẮT BUỘC bổ sung: Môi trường Cloudinary API thế hệ mới yêu cầu truyền rõ resource_type khi thực hiện destroy tệp Signed
          'resource_type': resourceType,
        },
      );

      developer.log('-------> [Cloudinary] DELETE RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Trạng thái thành công realtime trả về từ server là 'ok'
        if (data['result'] == 'ok') {
          developer.log('✅ Đã xóa file thành công trên Cloudinary: $publicId');
          return true;
        } else if (data['result'] == 'not_found') {
          developer.log('⚠️ Cloudinary thông báo không tìm thấy file hoặc đã bị xóa trước đó.');
          return true; // Trả về true để app bỏ qua và cập nhật UI luôn
        }
      }
    } catch (e) {
      developer.log('❌ deleteFile error: $e');
    }

    return false;
  }

  // ════════════════════════════════════════
  // UPLOAD IMAGE (Multipart Stream)
  // ════════════════════════════════════════
  Future<String?> uploadImage(File file, String userId, {bool isDrawing = false, bool isAvatar = false}) async {
    try {
      // 🔍 DEBUG: Xác minh env values trước khi upload
      developer.log('🔍 [Cloudinary] cloudName="$_cloudName" preset="$_uploadPreset"');
      developer.log('🔍 [Cloudinary] uploadImage URL: $_baseUrl/image/upload');

      if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
        developer.log('❌ [Cloudinary] ENV rỗng! Kiểm tra pubspec.yaml assets và file .env');
        return null;
      }

      final uri = Uri.parse('$_baseUrl/image/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = _uploadPreset;
      if (isAvatar) {
        request.fields['folder'] = 'smart_note/$userId/avatars';
      } else {
        request.fields['folder'] = isDrawing ? 'smart_note/$userId/drawings' : 'smart_note/$userId/images';
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      developer.log('📥 IMAGE RESPONSE [${response.statusCode}]: $responseData');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        return data['secure_url'];
      } else {
        developer.log('❌ [Cloudinary] Image upload failed HTTP ${response.statusCode}: $responseData');
      }
    } catch (e, stack) {
      developer.log('❌ uploadImage error: $e', error: e, stackTrace: stack);
    }
    return null;
  }

  // ════════════════════════════════════════
  // UPLOAD AUDIO (Multipart Stream)
  // ════════════════════════════════════════
  Future<String?> uploadAudio(File file, String userId) async {
    try {
      // 🔍 DEBUG: Xác minh env values trước khi upload
      developer.log('🔍 [Cloudinary] cloudName="$_cloudName" preset="$_uploadPreset"');
      developer.log('🔍 [Cloudinary] uploadAudio URL: $_baseUrl/video/upload');

      if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
        developer.log('❌ [Cloudinary] ENV rỗng! Kiểm tra pubspec.yaml assets và file .env');
        return null;
      }

      // Giữ nguyên endpoint video/upload của Cloudinary
      final uri = Uri.parse('$_baseUrl/video/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smart_note/$userId/audio';
      // resource_type được xác định bởi URL path 'video/upload' — hoặc set tường minh để đảm bảo an toàn
      request.fields['resource_type'] = 'video';

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      developer.log('📥 AUDIO RESPONSE [${response.statusCode}]: $responseData');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        return data['secure_url']; // URL trả về bây giờ sẽ có đuôi tệp chuẩn âm thanh
      } else {
        developer.log('❌ [Cloudinary] Audio upload failed HTTP ${response.statusCode}: $responseData');
      }
    } catch (e, stack) {
      developer.log('❌ uploadAudio error: $e', error: e, stackTrace: stack);
    }
    return null;
  }

  // ════════════════════════════════════════
  // PICK IMAGE FROM GALLERY
  // ════════════════════════════════════════
  Future<String?> pickAndUploadImage(String userId) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (picked == null) return null;

      return await uploadImage(File(picked.path), userId);
    } catch (e) {
      developer.log('❌ pick image error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════
  // CAMERA IMAGE
  // ════════════════════════════════════════
  Future<String?> cameraAndUploadImage(String userId) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
      );

      if (picked == null) return null;

      return await uploadImage(File(picked.path), userId);
    } catch (e) {
      developer.log('❌ camera image error: $e');
      return null;
    }
  }
}