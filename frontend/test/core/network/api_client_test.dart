import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_client.dart';

/// 서버가 준 이미지 주소를 앱이 읽을 수 있는 주소로 바꾸는 부분.
///
/// 기본 서버 주소(`http://10.0.2.2:8080`)를 그대로 쓴다. 테스트 실행에는
/// `--dart-define` 이 없으므로 [String.fromEnvironment] 의 기본값이 잡힌다.
void main() {
  const baseUrl = 'http://10.0.2.2:8080';

  group('ApiClient.imageUrl', () {
    test('저장소 key 앞에 서버 주소를 붙인다', () {
      expect(
        ApiClient.imageUrl('poster/poster_main_kim_feel.gif'),
        '$baseUrl/poster/poster_main_kim_feel.gif',
      );
    });

    test('앞에 슬래시가 있어도 주소가 겹치지 않는다', () {
      expect(ApiClient.imageUrl('/poster/a.gif'), '$baseUrl/poster/a.gif');
    });

    // 이미지 저장소가 S3 로 바뀌면 완전한 URL 이 온다. 그때 이 함수와 호출부를
    // 손대지 않아도 되는지가 여기서 갈린다.
    test('이미 절대 주소면 그대로 둔다', () {
      const s3 = 'https://timo-images.s3.amazonaws.com/poster/a.gif';
      expect(ApiClient.imageUrl(s3), s3);
    });

    // 포스터가 없는 공연이다. null 을 돌려줘야 PosterImage 가 회색 자리를 그린다.
    test('주소가 없거나 비어 있으면 null', () {
      expect(ApiClient.imageUrl(null), isNull);
      expect(ApiClient.imageUrl(''), isNull);
    });
  });
}
