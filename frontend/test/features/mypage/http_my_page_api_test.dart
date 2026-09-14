import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/mypage/constants.dart';
import 'package:timo/features/mypage/data/http_my_page_api.dart';
import 'package:timo/features/mypage/data/mock_my_page_data.dart';

import '../../core/network/fake_http_adapter.dart';

/// 실제 서버 구현이 백엔드 규약대로 요청하고 응답을 읽는지, 가짜 서버로 검사한다.
///
/// 주소·응답 키는 백엔드 `MemberController` · `MemberMeResponseDto` 에서 그대로
/// 가져왔다. 백엔드가 바뀌면 이 테스트를 같이 고쳐야 한다.
void main() {
  late FakeHttpAdapter adapter;

  HttpMyPageApi build(
    FutureOr<ResponseBody> Function(RecordedRequest) respond,
  ) {
    adapter = FakeHttpAdapter(respond);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    return HttpMyPageApi(dio: dio);
  }

  /// `MemberMeResponseDto` 모양. 실명·전화번호도 온다.
  Map<String, Object?> me({int memberId = 7, String nickname = '엥간한 닉네임'}) => {
    'memberId': memberId,
    'username': 'uzin',
    'name': '홍길동',
    'nickname': nickname,
    'phoneNumber': '010-****-5678',
  };

  group('내 정보', () {
    test('/members/me 를 GET 으로 요청하고 회원 번호·닉네임을 읽는다', () async {
      final api = build((_) => jsonResponse(me()));

      final profile = await api.fetchProfile();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '${HttpMyPageApi.basePath}/me');
      expect(request.rawBody, isNull);
      expect(profile.memberId, 7);
      expect(profile.nickname, '엥간한 닉네임');
    });

    test('로그인이 풀렸으면(401) 서버 문구를 담은 ApiException 을 던진다', () {
      final api = build(
        (_) => problemResponse(
          status: 401,
          errorMessage: '로그인이 필요해요.',
          exception: 'UnauthorizedException',
        ),
      );

      expect(
        api.fetchProfile(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 401)
              .having((e) => e.message, 'message', '로그인이 필요해요.'),
        ),
      );
    });

    test('네트워크가 끊기면 ApiException 을 던진다', () {
      final api = build(
        (request) => throw DioException.connectionError(
          requestOptions: request.options,
          reason: 'offline',
        ),
      );

      expect(api.fetchProfile(), throwsA(isA<ApiException>()));
    });

    test('본문이 JSON 객체가 아니면 읽을 수 없다는 ApiException 을 던진다', () {
      final api = build(
        (_) => ResponseBody.fromString(
          '<html>Bad Gateway</html>',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );

      expect(
        api.fetchProfile(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            MyPageStrings.unreadableResponse,
          ),
        ),
      );
    });
  });

  group('지갑', () {
    test('아직 서버 API 가 없어 요청을 보내지 않고 목업을 돌려준다', () async {
      final api = build((_) => fail('요청이 나가면 안 된다'));

      final wallet = await api.fetchWallet();

      expect(adapter.requests, isEmpty);
      expect(wallet.balance, MockMyPageData.wallet.balance);
      expect(wallet.transactions, MockMyPageData.wallet.transactions);
    });
  });
}
