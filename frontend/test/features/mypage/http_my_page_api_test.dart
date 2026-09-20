import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/mypage/constants.dart';
import 'package:timo/features/mypage/data/http_my_page_api.dart';

import '../../core/network/fake_http_adapter.dart';

/// 실제 서버 구현이 백엔드 규약대로 요청하고 응답을 읽는지, 가짜 서버로 검사한다.
///
/// 주소·응답 키는 백엔드 회원 API 명세(`/members/me`, `/members/wallet`)에서
/// 그대로 가져왔다. 백엔드가 바뀌면 이 테스트를 같이 고쳐야 한다.
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
    /// 지갑 응답 모양. 조회와 충전이 같은 형식을 돌려준다.
    Map<String, Object?> wallet({int balance = 1000000}) => {
      'balance': balance,
      'transactions': [
        {
          'title': '버섯 충전',
          'amount': 1000000,
          'balanceAfter': 1000000,
          'occurredAt': '2026-09-16T13:50:01.123456',
          'source': 'PG 모의 결제',
        },
      ],
    };

    test('/members/wallet 을 GET 으로 요청하고 잔액·내역을 읽는다', () async {
      final api = build((_) => jsonResponse(wallet()));

      final summary = await api.fetchWallet();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, HttpMyPageApi.walletPath);
      expect(request.rawBody, isNull);
      expect(summary.balance, 1000000);

      final transaction = summary.transactions.single;
      expect(transaction.title, '버섯 충전');
      expect(transaction.amount, 1000000);
      expect(transaction.balanceAfter, 1000000);
      expect(
        transaction.occurredAt,
        DateTime(2026, 9, 16, 13, 50, 1, 123, 456),
      );
      expect(transaction.source, 'PG 모의 결제');
      expect(transaction.isCredit, isTrue);
    });

    test('충전은 금액만 본문에 담아 POST 하고 충전 뒤 지갑을 읽는다', () async {
      final api = build((_) => jsonResponse(wallet(balance: 1150000)));

      final summary = await api.charge(1000000);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, HttpMyPageApi.chargePath);
      // 대상 회원은 토큰이 정하므로 memberId 를 실어 보내지 않는다.
      expect(request.jsonBody, {'amount': 1000000});
      expect(summary.balance, 1150000);
    });

    test('서버가 거절한 금액(400)은 서버 문구를 담은 ApiException 이 된다', () {
      final api = build(
        (_) => problemResponse(
          status: 400,
          errorMessage: '충전 금액은 0보다 커야 해요.',
          exception: 'IllegalArgumentException',
        ),
      );

      expect(
        api.charge(0),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.message, 'message', '충전 금액은 0보다 커야 해요.'),
        ),
      );
    });
  });
}
