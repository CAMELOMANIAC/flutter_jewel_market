# flutter_jewel_market

A new Flutter project.

## Getting Started

flutterfire cli를 설치하였으므로 아래 명령어를 입력하면 파이어베이스에 자동으로 등록되고 파이어베이스 초기화 설정이 자동으로 적용됩니다(로그인이 필요할 수 있음)
`flutterfire configure`

혹시 라이브러리를 다시 설치해야한다면
`flutter pub get`

안드로이드로 빌드하고 싶다면
`flutter build apk --release`
로 만들고 파이어베이스 콘솔에서 직접 앱을 드래그앤 드롭해서 배포하면 되고

ios로 빌드하고 싶다면
`flutter build ios --release`
ios에서는 트랜스포터앱을 열어서 드래그 앤 드롭하고 전송을 누르면 서버로 전송됨

⚠️ **주의**  
ios 빌드할때 앱서명이 정상적으로 되었는지 확인하고 안되면 revoke눌러서 재발급
ios를 배포할때는 반드시 릴리즈 모드로 빌드된 앱만 가능
pubspec.yaml의 version: 1.0.0+8 고유 빌드 버전을 가지도록 수정해야 트랜스포터로 전송 가능
