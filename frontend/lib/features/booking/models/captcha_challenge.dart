import 'dart:convert';
import 'dart:typed_data';

/// 서버가 낸 보안문자 한 문제. 정답은 서버만 알고, 앱은 그림과 키만 받는다.
class CaptchaChallenge {
  const CaptchaChallenge({
    required this.captchaKey,
    required this.image,
    required this.expiresIn,
  });

  /// 그림은 base64 로 온다. 형식이 깨졌으면 [FormatException] 이다.
  factory CaptchaChallenge.fromJson(Map<String, dynamic> json) =>
      CaptchaChallenge(
        captchaKey: json['captchaKey'] as String,
        image: base64Decode(json['image'] as String),
        expiresIn: Duration(seconds: (json['expiresIn'] as num).toInt()),
      );

  /// 답을 확인할 때 그대로 돌려줄 키. 한 번 확인하면 맞든 틀리든 폐기된다.
  final String captchaKey;

  /// 그림 바이트. 형식(JPEG 등)은 `Image.memory` 가 바이트를 보고 알아낸다.
  final Uint8List image;

  /// 이 문제를 풀 수 있는 시간. 지나면 확인 요청이 404 로 온다.
  final Duration expiresIn;
}
