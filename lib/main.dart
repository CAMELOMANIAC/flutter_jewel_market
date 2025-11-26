import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jewel_market/external_web_view.dart';
import 'package:flutter_jewel_market/local_notification.dart';

final webViewKey = GlobalKey<ExternalWebViewState>(); //하위 위젯에 접근하기 위해 위젯 참조저장

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); //비동기 main과 네이티브가 동기화하기 위한 초기화

  await initializeNotifications(); //로컬알림 권한요청 및 초기화

  await Firebase.initializeApp(); //firebase sdk 초기화

  // 파이어베이스 알림 권한 요청
  NotificationSettings settings = await FirebaseMessaging.instance
      .requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('사용자가 알림 권한을 허용했습니다.');
  } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
    debugPrint('사용자가 알림 권한을 거부했습니다.');
  }

  String? fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint("FCM Token: $fcmToken");

  // 포어그라운드 메시지 리스너 설정
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    String currentTalkKey = "";
    dynamic pushData;
    if (message.data.containsKey("pushData")) {
      pushData = jsonDecode(message.data["pushData"]);
    }
    debugPrint('포어그라운드 메시지 받음: ${message.data}');
    if (pushData != null) {
      currentTalkKey = pushData["TALK_KEY"] ?? pushData["talkKey"] ?? "";
    }

    debugPrint(
      '포그라운드 메시지 처리중: {$currentTalkKey - ${webViewKey.currentState?.activatedTalkKey}}',
    );

    if (webViewKey.currentState?.activatedTalkKey != currentTalkKey) {
      //활성된 토크키랑 메세지가 같으면 웹뷰에 메세지를 날리지 말것
      if (message.data.containsKey("title")) {
        showSimpleNotification(
          message.data["title"],
          message.data["body"] ?? '',
          message,
        );
      }
      debugPrint('포어그라운드 메시지 처리: ${message.data}');
    }
  });

  // 앱이 백그라운드 상태에서 알림을 눌러 포그라운드로 왔을 때 처리
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    webViewKey.currentState?.handleFCMMessage(message);
    debugPrint('백그라운드 메시지 처리: ${message.data}');
  });

  // 앱이 완전히 종료된 상태에서 알림을 눌러 시작했을 때 처리(값을 받아서 웹뷰 위젯까지 넘김)
  RemoteMessage? initialMessage = await FirebaseMessaging.instance
      .getInitialMessage();

  runApp(MyApp(initialMessage: initialMessage));
}

class MyApp extends StatelessWidget {
  final RemoteMessage? initialMessage;
  const MyApp({super.key, this.initialMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: null,
        body: SafeArea(
          child: ExternalWebView(
            key: webViewKey,
            initialFCMMessage: initialMessage,
          ),
        ),
      ),
    );
  }
}
