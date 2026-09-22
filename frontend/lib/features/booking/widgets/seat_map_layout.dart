import 'package:flutter/painting.dart';

import '../models/seat.dart';
import '../models/zone.dart';

/// 구역이 공연장에서 어느 자리인지.
///
/// 구역도([VenueMap])가 그리는 자리 관계와 같다. 거기서는 무대 아래 좌·우에 두
/// 구역, 그 뒤에 가로로 긴 구역, 맨 아래에 2층이 온다. 좌석 배치도도 같은
/// 판단을 써야 두 그림이 어긋나지 않는다.
enum SeatZonePlace {
  /// 무대 왼편(A). 무대가 위쪽과 **오른쪽**에 있다.
  stageLeft,

  /// 무대 오른편(B). 무대가 위쪽과 **왼쪽**에 있다.
  stageRight,

  /// 무대 정면의 뒤쪽 구역(C). 앞 가운데만 무대이고 좌우는 A·B 구역이다.
  rear,

  /// 2층 왼쪽. 앞에 뒤쪽 구역이 있고 무대는 그 너머 오른쪽 위다.
  balconyLeft,

  /// 2층 가운데. 좌우로 치우치지 않는다.
  balconyCenter,

  /// 2층 오른쪽. 무대가 왼쪽 위다.
  balconyRight,
}

/// 구역 둘레에 무엇이 있는지. 좌석 배치도 가장자리에 그린다.
class ZoneSurroundings {
  const ZoneSurroundings({
    this.place = SeatZonePlace.rear,
    this.frontLeft,
    this.frontRight,
    this.front,
  });

  /// 구역 목록에서 이 구역의 자리와 이웃을 읽는다.
  ///
  /// 구역도와 같은 규칙(목록 순서가 곧 자리)이다. 목록을 못 받았거나 모르는
  /// 구역이면 무대만 위에 둔 기본 모습으로 돌아간다 — 배치도를 아예 못 그리는
  /// 것보다 낫다.
  factory ZoneSurroundings.of(List<Zone> zones, int zoneId) {
    final index = zones.indexWhere((zone) => zone.id == zoneId);
    if (index < 0) return const ZoneSurroundings();

    return switch (index) {
      0 => const ZoneSurroundings(place: SeatZonePlace.stageLeft),
      1 => const ZoneSurroundings(place: SeatZonePlace.stageRight),
      2 => ZoneSurroundings(
        place: SeatZonePlace.rear,
        frontLeft: zones[0].name,
        frontRight: zones[1].name,
      ),
      _ => ZoneSurroundings(
        place: _balconyPlace(index - 3, zones.length - 3),
        front: zones.length > 2 ? zones[2].name : null,
      ),
    };
  }

  /// 2층 줄에서 몇 번째인지로 좌·우를 가른다.
  ///
  /// 구역도가 2층 줄을 나누는 규칙과 같다(첫째가 왼쪽, 마지막이 오른쪽,
  /// 가운데는 치우치지 않음). 두 그림이 서로 다른 기울기를 그리지 않도록
  /// 규칙을 하나만 둔다.
  static SeatZonePlace _balconyPlace(int index, int count) {
    if (index == 0) return SeatZonePlace.balconyLeft;
    if (index == count - 1) return SeatZonePlace.balconyRight;
    return SeatZonePlace.balconyCenter;
  }

  final SeatZonePlace place;

  /// 앞 왼쪽·앞 오른쪽 구역 이름(뒤쪽 구역에서 본 A·B).
  final String? frontLeft;
  final String? frontRight;

  /// 바로 앞 구역 이름(2층에서 본 뒤쪽 구역).
  final String? front;
}

/// 구역 배치도의 좌표 계산.
///
/// 좌석 칸, 고정 열 라벨, 무대가 **같은 셈을 따로 하면 반드시 어긋난다.**
/// 열마다 배율이 다르고 통로만큼 자리가 밀리기 때문에, 한 줄이라도 다르게
/// 세면 라벨이 가리키는 열과 실제 열이 달라진다. 그래서 위젯이 아니라 이
/// 객체가 모든 자리를 계산하고, 그리는 쪽은 받아 쓰기만 한다.
///
/// 좌표는 배치도 안쪽(여백을 뺀 영역)의 왼쪽 위를 원점으로 한다. 열 라벨 폭은
/// 포함하지 않는다 — 라벨은 좌석과 다른 층에 그려지기 때문이다.
class SeatMapLayout {
  SeatMapLayout({
    required this.rowCount,
    required this.seatsPerRow,
    this.place = SeatZonePlace.rear,
    this.rowMargins = const [],
  });

  /// 좌석 배치에서 열마다 앞·뒤로 비어 있는 칸 수를 세어 만든다.
  factory SeatMapLayout.of({
    required List<List<Seat?>> rows,
    required int seatsPerRow,
    SeatZonePlace place = SeatZonePlace.rear,
  }) => SeatMapLayout(
    rowCount: rows.length,
    seatsPerRow: seatsPerRow,
    place: place,
    rowMargins: [for (final row in rows) marginOf(row)],
  );

  /// 한 열의 앞뒤 빈 칸 수. 통째로 빈 열은 밀 이유가 없으니 0 으로 본다.
  static ({int leading, int trailing}) marginOf(List<Seat?> row) {
    var leading = 0;
    while (leading < row.length && row[leading] == null) {
      leading++;
    }
    if (leading == row.length) return (leading: 0, trailing: 0);

    var trailing = 0;
    while (row[row.length - 1 - trailing] == null) {
      trailing++;
    }
    return (leading: leading, trailing: trailing);
  }

  /// 열 수(무대에서 먼 쪽으로 셈). 0 번째가 무대와 가장 가깝다.
  final int rowCount;

  /// 한 열의 자리 수. 통로로 빈 자리도 한 칸으로 센다.
  final int seatsPerRow;

  /// 공연장에서 이 구역의 자리. 짧은 열이 붙는 방향과 무대 띠 위치를 정한다.
  final SeatZonePlace place;

  /// 열마다 앞·뒤로 빈 칸이 몇 개인지. 비워 두면 모든 열이 꽉 찬 것으로 본다.
  ///
  /// **여기가 배치도 모양을 만든다.** 서버가 열마다 다른 수의 좌석을 주면
  /// (앞열 15석, 뒷열 25석처럼) 짧은 열에 빈 칸이 생기고, 그만큼 그 열을 무대
  /// 쪽으로 밀어 사다리꼴이 된다. 지금 데이터는 모든 열이 꽉 차 있어 밀 것이
  /// 없고 직사각형으로 보인다.
  final List<({int leading, int trailing})> rowMargins;

  /// 맨 뒷열 좌석 한 변. 권장 터치 타겟(44pt) 기준이다.
  ///
  /// 앞열은 이보다 작아진다([frontScale]). 대신 배치도 전체를 확대할 수 있으므로
  /// 정확히 누르기 어려우면 손가락으로 벌리면 된다.
  static const cellSize = 44.0;

  /// 셀 간격. 셀 + 간격 = 48px 로, Material 최소 터치 타겟(48dp) 피치가 된다.
  static const cellGap = 4.0;

  /// 열 라벨('15열') 폭. 구역명은 그리드 위에 이미 적혀 있으므로 열 번호만 둔다.
  static const labelWidth = 38.0;

  /// 캔버스 안쪽 여백. 없으면 열 라벨이 프레임 테두리에 붙는다.
  static const padding = EdgeInsets.fromLTRB(12, 8, 12, 8);

  /// 무대 띠 높이. 2층에서는 무대가 멀리 있으므로 얇게 그린다.
  static const stageHeight = 30.0;
  static const balconyStageHeight = 20.0;

  /// 이웃 구역 띠 높이(뒤쪽 구역에서 본 A·B, 2층에서 본 뒤쪽 구역).
  static const neighborHeight = 26.0;

  /// 띠와 띠 사이, 마지막 띠와 1열 사이 간격.
  static const bandGap = 6.0;
  static const stageGap = 12.0;

  /// 옆으로 무대가 붙는 구역(A·B)에서 옆 띠의 폭과 간격.
  static const sideBandWidth = 24.0;
  static const sideBandGap = 8.0;

  /// 통로 폭·깊이. 좌석 한 칸의 절반 남짓이면 '자리가 빠진 것'이 아니라
  /// '지나다니는 길'로 읽힌다.
  static const aisleWidth = 24.0;
  static const aisleDepth = 20.0;

  /// 짧은 열을 어느 쪽으로 붙일지. -1 이면 왼쪽, 0 이면 가운데, 1 이면 오른쪽.
  ///
  /// 무대가 있는 쪽으로 붙인다. A구역은 오른편이 무대라 오른쪽으로, B구역은
  /// 왼편이 무대라 왼쪽으로 모인다 — 구역도의 기울기와 같은 방향이다.
  /// 2층도 같은 규칙을 따른다. 왼쪽 2층은 무대가 오른쪽 위에 있어 그쪽으로,
  /// 오른쪽 2층은 왼쪽 위로 모인다 — 구역도의 기울기와 같다.
  double get _alignment => switch (place) {
    SeatZonePlace.stageLeft || SeatZonePlace.balconyLeft => 1,
    SeatZonePlace.stageRight || SeatZonePlace.balconyRight => -1,
    _ => 0,
  };

  /// 2층인지. 무대가 멀어 띠를 얇게 두고 앞 구역 띠를 하나 더 얹는다.
  bool get isBalcony =>
      place == SeatZonePlace.balconyLeft ||
      place == SeatZonePlace.balconyCenter ||
      place == SeatZonePlace.balconyRight;

  /// 옆에 무대 띠가 붙는 구역인지.
  bool get hasSideStage =>
      place == SeatZonePlace.stageLeft || place == SeatZonePlace.stageRight;

  /// 세로 통로를 둘 자리. 값은 **통로 바로 뒤에 오는 칸 번호**(0부터)다.
  /// 예를 들어 7 이면 여덟 번째 칸 앞에 길이 난다.
  ///
  /// 서버는 통로를 빈 자리로 알려 주기도 하지만 대개 격자를 꽉 채워 준다.
  /// 그대로 그리면 20석이 한 덩어리로 붙어 실제 공연장처럼 보이지 않으므로,
  /// 자리 수에 맞춰 덩어리를 나눈다.
  late final List<int> columnAisles = _dividers(
    seatsPerRow,
    wide: 15,
    narrow: 8,
  );

  /// 가로 통로를 둘 자리. 세로 통로와 같은 기준으로, 값은 **통로 바로 뒤에
  /// 오는 열 번호**(0부터)다.
  late final List<int> rowAisles = _dividers(rowCount, wide: 14, narrow: 7);

  /// [count] 칸을 두세 덩어리로 나누는 자리를 고른다. 덩어리가 너무 작아지면
  /// 통로가 아니라 어긋난 격자로 보이므로 기준보다 작으면 나누지 않는다.
  static List<int> _dividers(
    int count, {
    required int wide,
    required int narrow,
  }) {
    if (count >= wide) return [(count / 3).round(), (count * 2 / 3).round()];
    if (count >= narrow) return [(count / 2).round()];
    return const [];
  }

  /// [column] 앞에 놓인 통로 수.
  int _aislesBefore(int column) =>
      columnAisles.where((divider) => divider <= column).length;

  /// 격자 전체의 가로 길이. 칸 크기가 어느 열에서나 같으므로 한 값이다.
  double get contentWidth {
    if (seatsPerRow <= 0) return 0;
    return seatsPerRow * cellSize +
        (seatsPerRow - 1) * cellGap +
        columnAisles.length * aisleWidth;
  }

  /// [row] 에서 실제로 자리가 놓인 부분의 왼쪽 끝과 길이. 무대 띠를 이 줄에
  /// 맞추는 데 쓴다.
  ({double left, double width}) occupiedSpan(int row) {
    final margin = _marginAt(row);
    if (seatsPerRow - margin.leading - margin.trailing <= 0) {
      return (left: contentLeft, width: contentWidth);
    }

    final left = seatLeft(row, margin.leading);
    final right = seatLeft(row, seatsPerRow - 1 - margin.trailing) + cellSize;
    return (left: left, width: right - left);
  }

  ({int leading, int trailing}) _marginAt(int row) =>
      row >= 0 && row < rowMargins.length
      ? rowMargins[row]
      : (leading: 0, trailing: 0);

  /// 밀기 전 [column] 의 x. 칸과 간격, 그 앞에 지나온 통로를 더한 값이다.
  double _rawX(int column) =>
      column * (cellSize + cellGap) + _aislesBefore(column) * aisleWidth;

  /// 짧은 열을 옆으로 미는 거리.
  ///
  /// 기울기가 0 이면 앞뒤 빈 자리를 반씩 나눠 가운데에 놓고, 1 이면 뒤쪽 빈
  /// 자리를 전부 앞으로 당겨 오른쪽 끝에 붙인다(-1 이면 왼쪽 끝).
  ///
  /// 칸 수가 아니라 **길이로 재는 이유**: 빈 자리 사이에 통로가 끼어 있으면
  /// 칸 수로 센 거리가 실제 길이와 24px 씩 어긋난다.
  double _shiftOf(int row) {
    final margin = _marginAt(row);
    if (margin.leading == 0 && margin.trailing == 0) return 0;

    final leading = _rawX(margin.leading) - _rawX(0);
    final trailing = _rawX(seatsPerRow) - _rawX(seatsPerRow - margin.trailing);

    return (trailing - leading) / 2 + _alignment * (trailing + leading) / 2;
  }

  /// 옆 무대 띠가 차지하는 폭(간격 포함). 없으면 0.
  double get _sideSpace => hasSideStage ? sideBandWidth + sideBandGap : 0;

  /// 좌석 영역이 시작하는 x. 무대 띠가 왼쪽(B구역)이면 그만큼 밀린다.
  double get contentLeft => place == SeatZonePlace.stageRight ? _sideSpace : 0;

  /// 옆 무대 띠의 x.
  double get sideBandLeft =>
      place == SeatZonePlace.stageRight ? 0 : contentWidth + sideBandGap;

  /// 맨 앞열에서 자리가 놓인 구간. 위쪽 무대 띠를 이 줄에 맞춘다.
  ///
  /// 격자 전체 너비로 깔면, 앞열이 짧은 구역에서 자리도 없는 쪽까지 무대가 쭉
  /// 삐져나온다(사용자 확인). 무대는 맨 앞줄 바로 앞에 있는 것이니 그 줄에
  /// 맞추는 것이 맞다.
  double get frontRowLeft => occupiedSpan(0).left;

  double get frontRowWidth => occupiedSpan(0).width;

  /// 위쪽 무대 띠의 높이. 2층은 무대가 멀어 얇다.
  double get stageBandHeight => isBalcony ? balconyStageHeight : stageHeight;

  /// 2층에서 앞 구역 띠의 y.
  double get frontBandTop => stageBandHeight + bandGap;

  /// 띠들이 1열 위에서 차지하는 높이.
  double get frontDepth => isBalcony
      ? stageBandHeight + bandGap + neighborHeight + stageGap
      : stageBandHeight + stageGap;

  /// [row] 의 위쪽 좌표. 앞 열들의 높이와 통로 깊이를 모두 더한 값이다.
  ///
  /// 열은 곧은 수평선이다. 무대를 감싸듯 굽혀도 봤지만 맨 앞줄 가운데가 볼록
  /// 튀어나와 배치도가 기울어 보였다(사용자 확인). 무대를 향한 방향은 사다리꼴과
  /// 무대 띠가 이미 말해 준다.
  double rowTop(int row) {
    var top = frontDepth + row * (cellSize + cellGap);
    for (var i = 0; i < row; i++) {
      // 통로는 '다음 열 앞'에 난다. 세로 통로와 세는 기준을 맞춘 것이다.
      if (rowAisles.contains(i + 1)) top += aisleDepth;
    }
    return top;
  }

  /// 좌석이 놓인 영역의 아래 끝. 옆 무대 띠의 높이를 여기에 맞춘다.
  double get rowsBottom =>
      rowCount <= 0 ? frontDepth : rowTop(rowCount - 1) + cellSize;

  /// 좌석 왼쪽 좌표.
  ///
  /// 칸 크기는 어느 열에서나 44px 로 같다(사용자 결정). 열마다 길이가 달라지는
  /// 것은 **자리 수가 다를 때뿐**이고, 그때 짧은 열이 [_shiftOf] 만큼 무대 쪽으로
  /// 밀리며 사다리꼴이 된다.
  double seatLeft(int row, int column) =>
      contentLeft + _rawX(column) + _shiftOf(row);

  /// 여백까지 포함한 캔버스 크기. [InteractiveViewer] 가 이 크기로 좌석을
  /// 펼쳐 놓고, 축소 한계도 이 값으로 정한다.
  double get canvasWidth =>
      padding.horizontal + labelWidth + _sideSpace + contentWidth;

  double get canvasHeight => padding.vertical + rowsBottom;
}
