import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jewel_market/external_web_view.dart';

final webViewKey = GlobalKey<ExternalWebViewState>(); //하위 위젯에 접근하기 위해 위젯 참조저장

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); //비동기 main과 네이티브가 동기화하기 위한 초기화
  await Firebase.initializeApp(); //firebase sdk 초기화

  // 알림 권한 요청
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

  // 포그라운드 메시지 리스너 설정
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // GlobalKey를 사용해 _ExternalWebViewState의 메서드를 호출합니다.
    webViewKey.currentState?.handleFCMMessage(message);
    debugPrint('포어그라운드 메시지 처리: ${message.data}');
  });

  // 백그라운드 메세지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

//백그라운드에서는 main대신 이 함수가 진입점 역할을 합니다.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  webViewKey.currentState?.handleFCMMessage(message);
  debugPrint('백그라운드 메시지 처리: ${message.data}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: null,
        body: SafeArea(child: ExternalWebView(key: webViewKey)),
      ),
    );
  }
}
