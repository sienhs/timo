# Firebase Cloud Messaging 설정

## 1. Firebase 프로젝트와 Flutter 앱 연결

Firebase Console에서 Android 앱을 등록할 때 패키지명은 `com.ssafy.timo`로 입력한다.
`frontend/`에서 아래 명령을 실행하면 `google-services.json`과 `lib/firebase_options.dart`가 생성된다.

```powershell
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android
```

`google-services.json`은 Android 앱 식별 설정이므로 `frontend/android/app/`에 둔다. 서비스 계정
비밀키와는 다르며, 서비스 계정 JSON은 절대 Git에 넣지 않는다.

## 2. 백엔드 자격증명과 활성화

Firebase Console → 프로젝트 설정 → 서비스 계정에서 키를 발급한다. 이 프로젝트의 운영 배포는
Terraform이 키를 Secrets Manager에 넣고 EC2에서 `/etc/timo/firebase-service-account.json`으로 복원한다.
키를 Git이나 `terraform.tfvars`에 넣지 않는다.

```powershell
$env:TF_VAR_firebase_service_account_json_base64 = [Convert]::ToBase64String(
  [IO.File]::ReadAllBytes('C:\secure\firebase-service-account.json')
)
terraform '-chdir=infra' apply
```

Google Cloud에서 실행할 때는 워크로드 서비스 계정(ADC)을 쓰도록 배포 구성을 바꿀 수 있다.
FCM HTTP v1 API도 Firebase Console의 Cloud Messaging 설정에서 활성화한다.

## 3. 도메인 코드에서 발송

예매·결제·양도 등 어떤 도메인 서비스든 `MemberPushNotificationService`를 주입한다.

```java
memberPushNotificationService.send(memberId,
        new PushMessage("예매 완료", "내 티켓에서 확인해 보세요.",
                Map.of("route", "/my-tickets", "reservationId", reservationId.toString())));
```

알림 등록 API는 로그인 사용자의 토큰만 저장한다.

* `PUT /api/v1/notifications/devices` — `{ "token": "...", "platform": "android" }`
* `DELETE /api/v1/notifications/devices` — `{ "token": "..." }`

앱이 FCM 토큰을 자동으로 등록한다. 알림을 눌렀을 때의 `route` 처리 규칙은 제품별 화면 이동 규약이 정해진 뒤 Flutter의 `PushNotificationService`에 추가한다.
