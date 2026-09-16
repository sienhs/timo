import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/data/person_auto_layout.dart';

/// 손 배치가 없을 때 쓰는 자동 배치. Kotlin 에서 Dart 로 옮긴 계산이라,
/// 옮기면서 규칙이 바뀌지 않았는지 여기서 못을 박는다.
void main() {
  const canvas = PersonAutoLayout.canvasSize;

  Map<String, dynamic> person({
    String cropType = 'FULL_BODY',
    double? torsoLength,
    double? faceHeight,
    double bottomAnchor = 1,
    double scale = 1,
    double dx = 0,
    double dy = 0,
    int order = 0,
  }) => {
    'analysis': {
      'cropType': cropType,
      'bottomAnchor': bottomAnchor,
      'torsoLength': ?torsoLength,
      'faceHeight': ?faceHeight,
    },
    'scale': scale,
    'dx': dx,
    'dy': dy,
    'order': order,
  };

  const portrait = Size(600, 900);

  group('한 사람', () {
    test('캔버스 안에 여백을 남기고 가로 가운데에 선다', () {
      final rect = PersonAutoLayout.layout([person()], [portrait]).single;

      expect(rect.left, greaterThanOrEqualTo(-0.01));
      expect(rect.top, greaterThanOrEqualTo(-0.01));
      expect(rect.right, lessThanOrEqualTo(canvas.width + 0.01));
      expect(rect.bottom, lessThanOrEqualTo(canvas.height + 0.01));
      expect(rect.center.dx, closeTo(canvas.width / 2, 0.01));
      // 원본 비율이 유지된다.
      expect(rect.width / rect.height, closeTo(portrait.width / portrait.height, 0.001));
    });

    test('혼자면 dx 를 줘도 맞춤이 다시 가운데로 당긴다', () {
      // 마지막 맞춤 단계가 전체 덩어리를 캔버스 가운데에 놓기 때문이다.
      // dx 가 의미를 갖는 건 둘 이상일 때의 '서로 간격' 이다.
      final base = PersonAutoLayout.layout([person()], [portrait]).single;
      final moved = PersonAutoLayout.layout(
        [person(dx: 0.2)],
        [portrait],
      ).single;
      expect(moved.center.dx, closeTo(base.center.dx, 0.01));
    });

    test('둘일 때 dx 는 서로의 간격을 벌린다', () {
      double gap(double dx) {
        final rects = PersonAutoLayout.layout(
          [person(), person(dx: dx, order: 1)],
          [portrait, portrait],
        );
        return (rects[1].center.dx - rects[0].center.dx).abs();
      }

      expect(gap(0.3), greaterThan(gap(0)));
    });
  });

  group('두 사람', () {
    test('같은 바닥선을 밟는다', () {
      final rects = PersonAutoLayout.layout(
        [person(), person(order: 1)],
        [portrait, portrait],
      );
      expect(rects, hasLength(2));
      expect(rects[0].bottom, closeTo(rects[1].bottom, 0.01));
    });

    test('잘린 사진과 전신 사진의 키가 맞춰진다', () {
      // 같은 사람을 전신으로 찍은 것과 상반신만 찍은 것.
      final rects = PersonAutoLayout.layout(
        [
          person(cropType: 'FULL_BODY', torsoLength: 0.3),
          person(cropType: 'UPPER_BODY', torsoLength: 0.72, order: 1),
        ],
        [portrait, portrait],
      );
      // 상반신 쪽은 몸통이 화면을 더 크게 차지하므로 전신 추정치가 커지고,
      // 그만큼 작게 그려져야 둘의 실제 키가 비슷해진다.
      expect(rects[1].height, lessThan(rects[0].height));
    });

    test('둘을 합친 덩어리가 여백 안에 들어간다', () {
      final rects = PersonAutoLayout.layout(
        [person(scale: 2), person(scale: 2, dx: 0.4, order: 1)],
        [portrait, portrait],
      );
      final union = rects.reduce((a, b) => a.expandToInclude(b));
      expect(union.width, lessThanOrEqualTo(canvas.width - 2 * PersonAutoLayout.margin + 0.01));
      expect(union.height, lessThanOrEqualTo(canvas.height - 2 * PersonAutoLayout.margin + 0.01));
      expect(union.center.dx, closeTo(canvas.width / 2, 0.01));
      expect(union.center.dy, closeTo(canvas.height / 2, 0.01));
    });
  });

  test('bottomAnchor 는 사진 아래쪽 여백만큼 바닥선 아래로 내린다', () {
    // bottomAnchor 는 '사진 높이 중 어디가 인물의 발끝인가' 다. 1 이면 사진이
    // 발끝에서 끝나고, 작을수록 발 아래 여백이 남아 그만큼 더 내려가야 두
    // 사람의 발끝이 같은 선에 온다.
    final rects = PersonAutoLayout.layout(
      [person(), person(bottomAnchor: 0.6, order: 1)],
      [portrait, portrait],
    );
    expect(rects[1].bottom, greaterThan(rects[0].bottom));
  });

  test('단서가 하나도 없어도 계산이 무너지지 않는다', () {
    final rect = PersonAutoLayout.layout(
      [
        {'analysis': const <String, dynamic>{}},
      ],
      [portrait],
    ).single;
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
    expect(rect.width.isFinite && rect.height.isFinite, true);
  });
}
