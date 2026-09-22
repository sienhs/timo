import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../constants.dart';

/// 이미지 한 장을 주소에서 받아 기기 파일로 쓴다.
///
/// 소재(kit)와 서버 소장품 복원이 같은 이유로 쓴다 — 온디바이스 파이프라인과
/// 소장품 화면이 전부 기기 파일 경로만 읽기 때문이다.
///
/// 앱 공용 클라이언트([ApiClient])를 쓰지 않는다. 그쪽에는 `Authorization`
/// 헤더가 붙는데, 저장소(S3)는 모르는 인증 헤더가 붙은 요청을 거절한다.
/// 포스터를 `NetworkImage` 로 받는 것과 같은 조건으로 받는다.
Future<void> downloadImage(String url, String targetPath) async {
  try {
    await Dio(
      BaseOptions(
        connectTimeout: GoodsConstants.transferTimeout,
        receiveTimeout: GoodsConstants.transferTimeout,
      ),
    ).download(url, targetPath);
  } on DioException catch (e) {
    throw ApiException.from(e);
  }
}

/// 주소 끝의 확장자. 없으면 png 다 — 앱이 올리는 것은 전부 png 고, 소재는
/// 서버가 형식을 가려 받는다(jpg·png·webp·gif).
String imageExtension(String url) {
  final name = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return 'png';
  return name.substring(dot + 1).toLowerCase();
}
