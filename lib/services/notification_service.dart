// // lib/services/notification_service.dart

// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:permission_handler/permission_handler.dart';

// class NotificationService {
//   // Singleton
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();

//   static final FlutterLocalNotificationsPlugin _plugin =
//       FlutterLocalNotificationsPlugin();

//   static const String _channelId = "otp_channel";
//   static const String _channelName = "OTP Notifications";
//   static const String _channelDescription = "One-time password for login";

//   // Call this from main.dart
//   Future<void> init() async {
//     const AndroidInitializationSettings androidInit =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );

//     const InitializationSettings initSettings = InitializationSettings(
//       android: androidInit,
//       iOS: iosInit,
//     );

//     await _plugin.initialize(initSettings);

//     // Create high-priority channel (Android 8.0+)
//     if (Platform.isAndroid) {
//       await _createAndroidChannel();
//     }
//   }

//   Future<void> _createAndroidChannel() async {
//     AndroidNotificationChannel channel = AndroidNotificationChannel(
//       _channelId,
//       _channelName,
//       description: _channelDescription,
//       importance: Importance.max,
//       playSound: true,
//       sound: RawResourceAndroidNotificationSound(
//         'notification',
//       ), // notification.mp3 in raw/
//       enableVibration: true,
//       vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
//     );

//     await _plugin
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.createNotificationChannel(channel);
//   }

//   // Optional: Call this early if you want permission popup immediately
//   Future<bool> requestPermission() async {
//     try {
//       if (Platform.isIOS) {
//         final iosPlugin = _plugin
//             .resolvePlatformSpecificImplementation<
//               IOSFlutterLocalNotificationsPlugin
//             >();
//         final bool? granted = await iosPlugin?.requestPermissions(
//           alert: true,
//           badge: true,
//           sound: true,
//         );
//         return granted ?? false;
//       }

//       if (Platform.isAndroid) {
//         // Use permission_handler safely
//         final status = await Permission.notification.status;
//         if (status.isDenied) {
//           final result = await Permission.notification.request();
//           return result.isGranted;
//         }
//         return status.isGranted;
//       }

//       return true;
//     } catch (e) {
//       debugPrint("Permission request error: $e");
//       return false;
//     }
//   }

//   // This is the method you call when OTP arrives
//   static Future<void> showOtpNotification(String otp) async {
//     final service = NotificationService();

//     // Request permission only the first time
//     final hasPermission = await service.requestPermission();
//     if (!hasPermission) {
//       debugPrint("Notification permission denied by user");
//       return;
//     }

//     AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       _channelId,
//       _channelName,
//       channelDescription: _channelDescription,
//       importance: Importance.max,
//       priority: Priority.high,
//       playSound: true,
//       sound: RawResourceAndroidNotificationSound('notification'),
//       enableVibration: true,
//       vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
//       ticker: 'OTP',
//       icon: '@mipmap/ic_launcher',
//     );

//     const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//       sound: 'notification.caf',
//     );

//     final NotificationDetails platformDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );

//     await _plugin.show(
//       999,
//       'Your OTP Code',
//       'Verification code: $otp',
//       platformDetails,
//     );
//   }
// }
// lib/services/notification_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = "otp_channel";
  static const String _channelName = "OTP Notifications";
  static const String _channelDescription = "One-time password for login";

  // Call this from main.dart
  Future<void> init() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    // Create high-priority channel (Android 8.0+)
    if (Platform.isAndroid) {
      await _createAndroidChannel();
    }
  }

  Future<void> _createAndroidChannel() async {
    // Use default notification sound instead of custom
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      // REMOVED: sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([
        0,
        500,
        1000,
        500,
      ]), // Shorter pattern
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // Optional: Call this early if you want permission popup immediately
  Future<bool> requestPermission() async {
    try {
      if (Platform.isIOS) {
        final iosPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final bool? granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      if (Platform.isAndroid) {
        // For Android 13+, we need notification permission
        if (Platform.isAndroid && (await Permission.notification.isDenied)) {
          final status = await Permission.notification.request();
          return status.isGranted;
        }
        return true; // For older Android versions
      }

      return true;
    } catch (e) {
      debugPrint("Permission request error: $e");
      return false;
    }
  }

  // This is the method you call when OTP arrives - SIMPLIFIED VERSION
  static Future<void> showOtpNotification(String otp) async {
    try {
      final service = NotificationService();

      // Request permission only the first time
      final hasPermission = await service.requestPermission();
      if (!hasPermission) {
        debugPrint("Notification permission denied by user");
        return;
      }

      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        // Use default system sound - this should work
        sound: const RawResourceAndroidNotificationSound(
          'notification',
        ), // Try default
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
        ticker: 'OTP',
        icon: '@mipmap/ic_launcher',
        color: Colors.purple, // Add color
        autoCancel: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // For iOS, use default sound
        // sound: 'default.caf',
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        999, // Unique ID
        'Your OTP Code',
        'Verification code: $otp\nValid for 5 minutes',
        platformDetails,
        payload: 'otp:$otp',
      );

      debugPrint("OTP notification shown successfully: $otp");
    } catch (e) {
      debugPrint("Error showing OTP notification: $e");

      // Fallback: Try without sound
      try {
        AndroidNotificationDetails fallbackDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: false, // Disable sound
          enableVibration: true,
          ticker: 'OTP',
          icon: '@mipmap/ic_launcher',
        );

        final NotificationDetails fallbackPlatformDetails = NotificationDetails(
          android: fallbackDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: false,
          ),
        );

        await _plugin.show(
          999,
          'Your OTP Code',
          'Verification code: $otp',
          fallbackPlatformDetails,
        );
      } catch (fallbackError) {
        debugPrint("Fallback notification also failed: $fallbackError");
      }
    }
  }

  // New method for general notifications without custom sound
  static Future<void> showSimpleNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        // Let Android use default sound
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        color: Colors.purple,
        autoCancel: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch % 10000,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint("Error showing simple notification: $e");
    }
  }
}
