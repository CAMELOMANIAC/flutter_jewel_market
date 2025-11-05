import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jewel_market/main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {

  // 초기화 설정 (InitializationSettings)
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // 플러그인 초기화 (initialize)
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) { //로컬노티 클릭시
      try {
        //payload를 Map으로 역직렬화
        final Map<String, dynamic> data = jsonDecode(response.payload!);

        final RemoteMessage syntheticMessage = RemoteMessage(
          data: data,
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        );

        webViewKey.currentState?.handleFCMMessage(syntheticMessage);

      } catch (e) {
        debugPrint('Payload JSON 파싱 오류: $e');
      }
    },
  );

  // 로컬 알림 권한 요청
  if (Platform.isAndroid) {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    final bool? granted = await androidImplementation
        ?.requestNotificationsPermission();
    if (granted != null && granted) {
      debugPrint('Android 알림 권한 허용됨');
    } else {
      debugPrint('Android 알림 권한 거부됨');
    }
  } else if (Platform.isIOS) {
    final bool? granted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (granted != null && granted) {
      debugPrint('iOS 알림 권한 허용됨');
    } else {
      debugPrint('iOS 알림 권한 거부됨');
    }
  }
}


Future<void> showSimpleNotification(String title, [String? contents, RemoteMessage? message]) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'default_channel_id', // 채널 ID
    '기본 알림', // 채널 이름
    channelDescription: '앱 기본 알림 채널',
    importance: Importance.max,
    priority: Priority.high,
  );

  const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();
  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iOSDetails,
  );

  final String payload = jsonEncode(message?.data);
  await flutterLocalNotificationsPlugin.show(
    0, // 알림 ID
    title, // 제목
    contents, // 본문
    notificationDetails,
    payload: payload, // 선택적: 클릭 시 전달할 데이터
  );
}
