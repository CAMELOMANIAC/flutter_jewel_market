import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';

class ExternalWebView extends StatefulWidget {
  const ExternalWebView({super.key});

  @override
  State<ExternalWebView> createState() => ExternalWebViewState();
}

class ExternalWebViewState extends State<ExternalWebView>
    with WidgetsBindingObserver {
  final String uri = "http://192.168.0.69:7443";
  InAppWebViewController? webViewController;

  void handleFCMMessage(RemoteMessage message) {
    final data = message.data;
    final jsonData = jsonEncode(data);
    webViewController?.evaluateJavascript(
      source:
          '''
      console.log("push");
      const pushData = JSON.parse('$jsonData');
      window.dispatchEvent(new CustomEvent("push", { detail: { pushType:pushType, pushData: pushData } }));
    ''',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
          document.dispatchEvent(new Event("backbutton"));
        ''',
      );
    } else {
      final bool canGoBack = await webViewController!.canGoBack();
      // 4. 외부 도메인인 경우
      // 외부 페이지에서는 네이티브 뒤로가기 기능을 직접 사용합니다.
      if (canGoBack) {
        webViewController!.goBack();
      } else {
        // 더 이상 뒤로 갈 수 없으면 앱을 닫습니다.
        SystemNavigator.pop();
      }
    }
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

  Future<PermissionResponse?> _requestPermissionHandler(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    // 카메라 또는 마이크 권한 요청이 들어오면 무조건 거부 추후에 업로드 기능 사진이나 파일을 찾아야하므로 변경 필요
    if (request.resources.contains(PermissionResourceType.CAMERA) ||
        request.resources.contains(PermissionResourceType.MICROPHONE)) {
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
    return PopScope(
      canPop: false, //기본 history.back()을 하지 못하도록 합니다.
      onPopInvokedWithResult: //원래 플러터는 코르도바와 달리 자동으로 history.back()을 호출하지만
          _onPopInvokedWithResult, //기존 코드 호환을 위해 backbutton 이벤트를 트리거하도록 정의
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(uri)),
        onWebViewCreated: (controller) {
          webViewController = controller;
          flutterCloseEventHandler(); //웹뷰가 종료 신호를 보내는 경우 종료하는 함수
        },
        onPermissionRequest: _requestPermissionHandler,
      ),
    );
  }
}
