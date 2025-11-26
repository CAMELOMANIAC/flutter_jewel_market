import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';

class ExternalWebView extends StatefulWidget {
  final RemoteMessage? initialFCMMessage;
  const ExternalWebView({super.key, this.initialFCMMessage});

  @override
  State<ExternalWebView> createState() => ExternalWebViewState();
}

class ExternalWebViewState extends State<ExternalWebView>
    with WidgetsBindingObserver {
  final String uri = "https://dev.jewelmarket.kr:7443";
  InAppWebViewController? webViewController;
  RemoteMessage? _pendingFCMMessage;
  bool isWebReady = false;
  String activatedTalkKey = "";

  void handleFCMMessage(RemoteMessage message) {
    _pendingFCMMessage = message;
    debugPrint('handleFCMMessage에서 ${_pendingFCMMessage?.data}');
    // 웹뷰가 이미 로드 완료 상태인지 확인하고 바로 전달 시도
    if (webViewController != null) {
      _sendPendingMessage();
    }
  }

  void _sendPendingMessage() {
    final data = _pendingFCMMessage?.data;
    if (data == null || webViewController == null) return;

    // 각 필드 추출
    final pushType = data['pushType'];
    final body = data['body'];
    final title = data['title'];

    // pushData는 문자열 또는 Map일 수 있으므로 안전하게 파싱
    Map<String, dynamic>? pushDataMap;
    final rawPushData = data['pushData'];

    if (rawPushData is String) {
      try {
        pushDataMap = jsonDecode(rawPushData);
      } catch (e) {
        debugPrint("pushData JSON decode error: $e");
      }
    } else if (rawPushData is Map) {
      pushDataMap = Map<String, dynamic>.from(rawPushData);
    }

    // WebMessage로 보낼 전체 payload 구성
    final messagePayload = {
      "event": "push", // JS에서 이벤트 구분용
      "payload": {
        "pushType": pushType,
        "title": title,
        "body": body,
        "pushData": pushDataMap,
      },
    };

    if (isWebReady) {
      webViewController!.postWebMessage(
        message: WebMessage(data: jsonEncode(messagePayload)),
      );
      debugPrint("FCM Message 전송 선공: $messagePayload");
      _pendingFCMMessage = null;
    } else {
      debugPrint("FCM Message 전송 실패: $isWebReady");
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialFCMMessage != null) {
      handleFCMMessage(widget.initialFCMMessage!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (webViewController == null) {
      // 컨트롤러가 아직 준비되지 않았으면 아무것도 하지 않고 함수 종료
      debugPrint("웹뷰 컨트롤러가 아직 초기화되지 않았습니다. 생명 주기 변경 무시.");
      return;
    }

    if (state == AppLifecycleState.paused) {
      //코르도바와 달리 pause, resume를 자동으로 발생시키지 않으므로 직접 WidgetsBindingObserver로 감지해서 js이벤트를 트리거시켜야함
      webViewController?.evaluateJavascript(
        source: '''
          console.log("pause")
          window.dispatchEvent(new Event("pause"));
        ''',
      );
    } else if (state == AppLifecycleState.resumed) {
      webViewController?.evaluateJavascript(
        source: '''
          console.log("resume")
          window.dispatchEvent(new Event("resume"));
        ''',
      );
    }
  }

  // onPopInvoked는 뒤로가기 동작이 요청되었을 때 호출됩니다.
  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    if (webViewController == null) {
      // 컨트롤러가 아직 준비되지 않았으면 아무것도 하지 않고 함수 종료
      debugPrint("웹뷰 컨트롤러가 아직 초기화되지 않았습니다. 생명 주기 변경 무시.");
      return;
    }

    // 1. 현재 웹뷰의 URL을 가져옵니다.
    final currentUrl = await webViewController!.getUrl();
    final uriObject = Uri.parse(uri);
    final ourHost = uriObject.host;
    final ourPort = uriObject.port;

    // 2. 자사 도메인을 판별하는 로직을 만듭니다.
    final isOurDomain =
        currentUrl?.host == ourHost && currentUrl?.port == ourPort;

    // 3. 자사 도메인인 경우
    if (isOurDomain) {
      // 자사 페이지에서는 코르도바의 backbutton 이벤트를 재현합니다.
      webViewController?.evaluateJavascript(
        source: '''
          console.log("backbutton",theApp.mainNavi.curHisIndex)
          window.dispatchEvent(new Event("backbutton"));
        ''',
      );
    } else {
      final bool canGoBack = await webViewController!.canGoBack();
      // 4. 외부 도메인인 경우(외부 페이지에서는 네이티브 뒤로가기 기능을 직접 사용합니다.)
      if (canGoBack) {
        webViewController!.goBack();
      } else {
        // 더 이상 뒤로 갈 수 없으면 앱을 닫습니다.
        SystemNavigator.pop();
      }
    }
  }

  void webReadyHandShakeHandler() {
    webViewController?.addJavaScriptHandler(
      handlerName: "webReady",
      callback: (args) {
        setState(() {
          isWebReady = true;
        });
        debugPrint("플러터: 웹뷰 준비 완료");
        _sendPendingMessage(); // 대기 중인 메시지 전송
      },
    );
  }

  //웹뷰가 종료 신호를 보내는 경우 종료하는 함수
  void flutterCloseEventHandler() {
    webViewController?.addJavaScriptHandler(
      handlerName: 'closeAppHandler',
      callback: (args) {
        SystemNavigator.pop();
      },
    );
  }

  //기기 fcm 토큰을 가져오는 함수
  void fcmTokenEventHandler() {
    webViewController?.addJavaScriptHandler(
      handlerName: 'getFcmTokenHandler',
      callback: (args) {
        return FirebaseMessaging.instance.getToken();
      },
    );
  }

  void activatedTalkKeyHandler() {
    webViewController?.addJavaScriptHandler(
      handlerName: 'setActivatedTalkKeyHandler',
      callback: (args) {
        activatedTalkKey = args[0];
        debugPrint("setActivatedTalkKeyHandler $activatedTalkKey");
      },
    );
  }

  Future<PermissionResponse?> _requestPermissionHandler(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    // 카메라 또는 마이크 권한 요청이 들어오면 무조건 거부 추후에 업로드 기능 사진이나 파일을 찾아야하므로 변경 필요
    // if (request.resources.contains(PermissionResourceType.CAMERA) ||
    //     request.resources.contains(PermissionResourceType.MICROPHONE)) {

    if (request.resources.contains(PermissionResourceType.MICROPHONE)) {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY, // 권한 거부
      );
    }
    return PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.GRANT, // 다른 권한은 허용 (필요에 따라 변경)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PopScope(
          canPop: false, //기본 history.back()을 하지 못하도록 합니다.
          onPopInvokedWithResult: //원래 플러터는 코르도바와 달리 자동으로 history.back()을 호출하지만
              _onPopInvokedWithResult, //기존 코드 호환을 위해 backbutton 이벤트를 트리거하도록 정의
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(uri)),
            onWebViewCreated: (controller) {
              webViewController = controller;
              fcmTokenEventHandler();
              webReadyHandShakeHandler();
            },
            onLoadStop: (controller, url) {
              //웹뷰가 완전히 로드된 후 실행할 이벤트
              flutterCloseEventHandler(); //웹뷰가 종료 신호를 보내는 경우 종료하는 함수
              activatedTalkKeyHandler();
            },
            onPermissionRequest: _requestPermissionHandler,
            initialSettings: InAppWebViewSettings(
              isInspectable: kDebugMode ? true : false,
            ), //ios용 웹인스펙터 디버깅 설정 추가
          ),
        ),
        isWebReady ==
                false // 웹뷰가 준비되지 않을때 보여 줄 폴백 출력
            ? Container(
                color: Colors.white,
                child: Center(child: CircularProgressIndicator()),
              )
            : const SizedBox.shrink(),
      ],
    );
  }
}
