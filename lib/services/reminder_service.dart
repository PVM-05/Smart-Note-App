import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note_model.dart';
import '../services/local_note_service.dart';
import '../screens/editor_screen.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Navigator key toàn cục dùng để điều hướng trực tiếp khi click thông báo
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? _coldStartPayload;

  Future<void> init() async {
    // 1. Khởi tạo timezone
    tz.initializeTimeZones();
    String timeZoneName = 'UTC';
    try {
      timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      log('⏰ Timezone initialized: $timeZoneName');
    } catch (e) {
      log('⚠️ Error setting timezone location: $e. Falling back to UTC.');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    // 2. Thiết lập cài đặt cho Android & iOS
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        final payload = details.payload;
        log('🔔 Notification clicked with payload: $payload');
        if (payload != null && payload.isNotEmpty) {
          navigateToNote(payload);
        }
      },
    );
    log('🔔 FlutterLocalNotifications initialized.');

    // 3. Kiểm tra chi tiết launch app (Cold Start)
    try {
      final details = await _localNotificationsPlugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        _coldStartPayload = details.notificationResponse?.payload;
        log('❄️ Cold start payload detected: $_coldStartPayload');
      }
    } catch (e) {
      log('⚠️ Error fetching launch details: $e');
    }
  }

  // Trả về và xóa payload cold start để tránh việc tiêu thụ lại nhiều lần
  String? consumeColdStartPayload() {
    final payload = _coldStartPayload;
    _coldStartPayload = null;
    return payload;
  }

  // Điều hướng trực tiếp đến trang chi tiết ghi chú dựa trên noteId
  static Future<void> navigateToNote(String noteId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        log('⚠️ Không thể điều hướng: Người dùng chưa đăng nhập.');
        return;
      }

      final note = await LocalNoteService().getNoteById(noteId);
      if (note != null) {
        if (note.userId != currentUser.uid) {
          log('⚠️ Không thể điều hướng: Ghi chú $noteId không thuộc về người dùng hiện tại.');
          return;
        }

        log('🚀 Điều hướng thẳng đến ghi chú: $noteId');
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => EditorScreen(note: note),
          ),
        );
      } else {
        log('⚠️ Không thể điều hướng: Không tìm thấy ghi chú $noteId trong cơ sở dữ liệu.');
      }
    } catch (e) {
      log('❌ Lỗi điều hướng thông báo: $e');
    }
  }

  // Đồng bộ lại tất cả lịch nhắc nhở (dùng sau khi đồng bộ hóa dữ liệu đám mây)
  Future<void> syncReminders(List<Note> notes) async {
    log('♻️ Đang đồng bộ hóa lịch nhắc nhở từ danh sách Cloud Sync...');
    for (final note in notes) {
      if (note.status == 'trash') {
        await cancelReminder(note.id);
        continue;
      }
      if (note.reminder != null) {
        if (note.reminder!.isAfter(DateTime.now())) {
          String body;
          String? bigText;
          if (note.isChecklist) {
            final pendingCount = note.pendingChecklistCount;
            body = "Bạn có $pendingCount công việc chưa hoàn thành.";
            bigText = "$body\n${note.checklistPlainText}";
          } else {
            final plainText = note.plainTextContent;
            body = plainText.length > 100
                ? '${plainText.substring(0, 97)}...'
                : plainText;
            if (body.isEmpty) {
              body = 'Bạn có một nhắc nhở ghi chú!';
            }
          }
          await scheduleReminder(
            id: note.id,
            title: note.title.isNotEmpty ? note.title : 'Nhắc nhở ghi chú',
            body: body,
            bigText: bigText,
            scheduledDate: note.reminder!,
          );
        } else {
          // Lịch cũ hơn thời gian hiện tại, hủy cho sạch bộ nhớ hệ thống
          await cancelReminder(note.id);
        }
      } else {
        await cancelReminder(note.id);
      }
    }
  }

  // Yêu cầu quyền gửi thông báo
  Future<bool> requestPermissions() async {
    final androidImplementation = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    final iosImplementation = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  // Lên lịch thông báo
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required String body,
    String? bigText,
    required DateTime scheduledDate,
  }) async {
    // Tránh giá trị âm và giảm thiểu xung đột ID bằng phép chia lấy dư giới hạn 32-bit positive int
    final int notificationId = id.hashCode.abs() % 2147483647;
    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Nếu thời gian đã trôi qua thì không lên lịch
    if (tzScheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      log('⚠️ Không thể đặt nhắc nhở ở quá khứ cho note $id');
      return;
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'note_reminders_channel',
      'Nhắc nhở Ghi chú',
      channelDescription: 'Kênh nhận các thông báo nhắc nhở ghi chú',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      styleInformation: bigText != null ? BigTextStyleInformation(bigText) : null,
    );

    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    try {
      await _localNotificationsPlugin.zonedSchedule(
        notificationId,
        title.isNotEmpty ? title : 'Nhắc nhở ghi chú',
        body,
        tzScheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: id,
      );
      log('⏰ Đã lên lịch nhắc nhở chính xác cho note $id lúc $tzScheduledDate (hashId: $notificationId)');
    } catch (e) {
      log('⚠️ Không thể lên lịch chính xác (do giới hạn quyền Android 14+), tự động chuyển sang chế độ linh hoạt: $e');
      await _localNotificationsPlugin.zonedSchedule(
        notificationId,
        title.isNotEmpty ? title : 'Nhắc nhở ghi chú',
        body,
        tzScheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: id,
      );
      log('⏰ Đã lên lịch nhắc nhở linh hoạt cho note $id lúc $tzScheduledDate (hashId: $notificationId)');
    }
  }

  // Hủy thông báo
  Future<void> cancelReminder(String id) async {
    final int notificationId = id.hashCode.abs() % 2147483647;
    await _localNotificationsPlugin.cancel(notificationId);
    log('🚫 Đã hủy lịch nhắc nhở note $id (hashId: $notificationId)');
  }
}
