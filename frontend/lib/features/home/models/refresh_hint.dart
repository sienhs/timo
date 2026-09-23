/// 아래로 당길 때 보여 주는 안내 문구 한 줄. 한 낱말만 브랜드 색으로
/// 강조하므로 통 문자열이 아니라 세 조각으로 나눠 둔다.
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
