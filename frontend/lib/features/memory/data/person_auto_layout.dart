import 'dart:math' as math;
import 'dart:ui';

import 'person_placement.dart';

/// 손으로 배치하지 않은 사람들을 사진 속 몸 비율만 보고 자동으로 앉힌다.
///
/// 제작 화면은 사람을 추가할 때마다 `PersonPlacement.initial` 로 배치를 잡아
/// 주므로 앱에서는 보통 여기까지 오지 않는다. 배치가 없는 입력(다른 화면에서
/// 넘어온 사람, 기기 테스트)이 들어왔을 때 두 사람이 같은 바닥선 위에 서고,
/// 사진이 어떻게 잘렸든 서로 키가 맞게 만드는 것이 이 클래스의 일이다.
///
/// 원래 Kotlin(`CompositionProcessor`)에 있던 계산을 그대로 옮겼다. 픽셀을
/// 만지지 않는 순수 계산이라 네이티브에 있을 이유가 없었다. 옮기면서 캔버스를
/// 900×1200 에서 [PersonPlacement.canvasSize](900×1400)로 맞췄다 — 티켓이
/// 9:14 인데 합성본만 3:4 라서, 폴백으로 만든 소장품은 비율이 어긋나 있었다.
class PersonAutoLayout {
  PersonAutoLayout._();

  static const canvasSize = PersonPlacement.canvasSize;

  /// 합성본 가장자리에 남기는 여백(px).
  static const margin = 45.0;

  /// 최종 맞춤 전, 작업 캔버스에서의 전신 키(px).
  static const targetBody = 1000.0;

  /// 모두가 밟고 서는 바닥선. 캔버스 높이에 대한 비율이다.
  static const floorRatio = 1100 / 1200;

  // 인체 비율: 전신 키 ≈ 어깨-엉덩이 × 3.3 ≈ 얼굴 높이 × 7.5 ≈ 어깨 너비 × 4.0
  static const torsoToBody = 3.3;
  static const faceToBody = 7.5;
  static const shoulderToBody = 4.0;

  /// 전신 옆에 선 상반신은 더 앞에 서 있는 것으로 읽힌다. 그만큼 키운다.
  static const closerBonus = 1.08;

  static const _coverage = {
    'FULL_BODY': 1.00,
    'HALF_BODY': 0.62,
    'UPPER_BODY': 0.42,
  };

  static double _num(Map<dynamic, dynamic> map, String key, double fallback) {
    final value = map[key];
    return value is num ? value.toDouble() : fallback;
  }

  /// 쓸 수 있는 단서를 전부 "원본 픽셀 기준 전신 키" 추정치로 바꾼 뒤 신뢰도로
  /// 가중 평균한다. 그래야 사진이 어떻게 잘렸든, 얼굴이 잡혔든 아니든 두 사람이
  /// 같은 키 척도로 놓인다.
  static double bodyHeight(
    Map<dynamic, dynamic> analysis,
    double width,
    double height,
  ) {
    final cues = <(double estimate, double weight)>[];

    final torso = _num(analysis, 'torsoLength', 0);
    if (torso > 0.02) cues.add((torso * height * torsoToBody, 1.0));

    final face = _num(analysis, 'faceHeight', 0);
    if (face > 0.01) cues.add((face * height * faceToBody, 0.8));

    final shoulder = _num(analysis, 'shoulderWidth', 0);
    if (shoulder > 0.02) cues.add((shoulder * width * shoulderToBody, 0.4));

    // 어떤 단서도 없을 때를 위한 바닥값. 잘린 정도만으로 키를 되짚는다.
    final coverage = _coverage[analysis['cropType']] ?? 0.75;
    cues.add((height / coverage, 0.35));

    var weighted = 0.0, weights = 0.0;
    for (final (estimate, weight) in cues) {
      weighted += estimate * weight;
      weights += weight;
    }
    return weighted / weights;
  }

  /// 캔버스 픽셀 기준 최종 사각형들. 순서는 입력 순서(= 그리는 순서)다.
  ///
  /// [dims] 는 각 사람 이미지의 원본 크기다.
  static List<Rect> layout(
    List<Map<String, dynamic>> people,
    List<Size> dims,
  ) {
    assert(people.isNotEmpty && people.length <= 2);
    assert(dims.length == people.length);

    final width = canvasSize.width, height = canvasSize.height;
    final analyses = [
      for (final person in people)
        (person['analysis'] as Map<dynamic, dynamic>?) ?? const {},
    ];
    final anyFull = analyses.any((a) => a['cropType'] == 'FULL_BODY');

    final sizes = [
      for (var i = 0; i < people.length; i++)
        () {
          final dim = dims[i];
          final closer =
              people.length == 2 &&
                  anyFull &&
                  analyses[i]['cropType'] != 'FULL_BODY'
              ? closerBonus
              : 1.0;
          final scale =
              targetBody /
              bodyHeight(analyses[i], dim.width, dim.height) *
              closer *
              _num(people[i], 'scale', 1).clamp(0.5, 2.0);
          return Size(dim.width * scale, dim.height * scale);
        }(),
    ];

    final rects = [
      for (var i = 0; i < sizes.length; i++)
        () {
          final size = sizes[i];
          // 모두 같은 바닥선을 밟는다. 상반신만 있는 사진은 거기서 끝난다.
          final y =
              height * floorRatio -
              size.height * _num(analyses[i], 'bottomAnchor', 1);
          final x = people.length == 1
              ? -size.width / 2
              : (i == 0 ? -size.width * 0.88 : -size.width * 0.12);
          final dx = _num(people[i], 'dx', 0) * width;
          final dy = _num(people[i], 'dy', 0) * height;
          return Rect.fromLTWH(x + dx, y + dy, size.width, size.height);
        }(),
    ];

    // 전체를 한 덩어리로 보고 여백 안에 맞춰 넣은 뒤 가운데로 옮긴다.
    final union = rects.reduce((a, b) => a.expandToInclude(b));
    final fit = math.min(
      (width - 2 * margin) / union.width,
      (height - 2 * margin) / union.height,
    );
    return [
      for (final rect in rects)
        Rect.fromLTWH(
          (width - union.width * fit) / 2 + (rect.left - union.left) * fit,
          (height - union.height * fit) / 2 + (rect.top - union.top) * fit,
          rect.width * fit,
          rect.height * fit,
        ),
    ];
  }
}
