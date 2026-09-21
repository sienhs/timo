import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/constants.dart';

void main() {
  // 단계를 하나 늘릴 때 제목이나 부제 한 쪽만 빠뜨리면, 그 단계에 들어가기
  // 전까지는 아무 일도 없다가 화면에서 범위 밖 읽기로 터진다.
  test('단계 수만큼 제목과 부제가 있다', () {
    expect(CreatorText.titles, hasLength(CreatorText.totalSteps));
    expect(CreatorText.subtitles, hasLength(CreatorText.totalSteps));
  });

  test('인물 조정은 인물을 다 고른 뒤, 이펙트 앞이다', () {
    expect(CreatorText.titles[4], contains('인물을'));
    expect(CreatorText.titles.last, contains('이펙트'));
  });
}
