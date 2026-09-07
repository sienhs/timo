/// 아래로 당길 때 보여 주는 안내 문구 한 줄.
///
/// 문구 안의 한 낱말만 브랜드 색으로 강조하므로, 통 문자열이 아니라 세
/// 조각으로 나눠 둔다. `'... {기다리고} ...'` 처럼 표시를 넣어 파싱하는
/// 방법도 있지만, 조각이 필드로 드러나 있으면 무엇이 강조되는지 코드만
/// 보고 알 수 있고 오타로 표시가 깨질 일도 없다.
class RefreshHint {
  const RefreshHint({
    required this.before,
    required this.highlight,
    required this.after,
  });

  /// 강조 앞 부분.
  final String before;

  /// 브랜드 색으로 강조할 낱말.
  final String highlight;

  /// 강조 뒷 부분.
  final String after;

  /// 이어 붙인 전체 문구. 스크린 리더 라벨과 테스트에 쓴다.
  String get plainText => '$before$highlight$after';
}
