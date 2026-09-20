import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// 찜한 공연 한 건. 카드를 그릴 만큼만 담은 공연 요약이다.
///
/// 어디서 왔든 모양이 같다. 목록을 열 때는 서버가 준 찜 목록
/// (`ConcertSummaryResponseDto`)에서 [FavoriteShow.fromConcertSummaryJson] 으로
/// 만들고, 검색·상세에서 하트를 누른 순간에는 그 화면이 들고 있던 공연을
/// 바꿔서 만든다(`features/home/utils/favorite_targets.dart` 등). 뒤쪽은 서버
/// 응답을 기다리지 않고 카드를 그리기 위한 것이라, 목록을 다시 받으면 서버가
/// 준 모습으로 덮인다.
///
/// 홈의 `ShowSummary`·상세의 `ShowDetail` 을 그대로 쓰지 않는 이유는 어느
/// 화면에서 찜했든 찜리스트에서는 같은 모양이어야 해서다.
@immutable
class FavoriteShow {
  const FavoriteShow({
    required this.id,
    required this.title,
    required this.venueName,
    required this.isOnSale,
    this.posterImageUrl,
    this.startAt,
  });

  /// 서버의 공연 요약(`ConcertSummaryResponseDto`) 한 건을 읽는다.
  ///
  /// 포스터 주소는 서버가 준 저장소 key 그대로 둔다. 절대 주소로 바꾸는 일은
  /// 그리는 쪽(`PosterImage.network`)이 맡는다 — 홈의 `ShowSummary` 와 같다.
  factory FavoriteShow.fromConcertSummaryJson(Map<String, dynamic> json) =>
      FavoriteShow(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        venueName: json['venueName'] as String,
        isOnSale: _sellingStatuses.contains(json['status']),
        posterImageUrl: json['posterImageUrl'] as String?,
        startAt: switch (json['startDate']) {
          final String raw => DateTime.parse(raw),
          _ => null,
        },
      );

  /// 아직 살 수 있는 공연의 상태. 백엔드 `ConcertStatus` 의 상수명이다.
  ///
  /// 오픈 예정도 판매 중으로 친다. 찜리스트의 필터가 '판매 중 / 판매 종료'
  /// 둘뿐이라 곧 살 수 있는 공연을 종료 쪽에 넣을 수는 없다. 홈
  /// `ShowSummary.isOpenOrUpcoming` 과 같은 기준이다.
  static const _sellingStatuses = {'SCHEDULED', 'ON_SALE'};

  /// 서버가 준 공연 번호. 같은 공연인지는 이 값으로만 가른다.
  final int id;

  final String title;
  final String venueName;

  /// 예매를 앞두고 있거나 진행 중이면 참. 필터 칩(판매 중 · 판매 종료)이
  /// 이 값으로 가른다.
  final bool isOnSale;

  final String? posterImageUrl;

  /// 공연 시작 일시. 미정이면 null 이다.
  final DateTime? startAt;

  /// 카드에 찍는 일시. (예: `2026.11.20 19:00`)
  String get dateLabel {
    final start = startAt;
    return start == null
        ? FavoriteStrings.dateUndecided
        : formatPerformedAt(start);
  }

  @override
  bool operator ==(Object other) =>
      other is FavoriteShow &&
      other.id == id &&
      other.title == title &&
      other.venueName == venueName &&
      other.isOnSale == isOnSale &&
      other.posterImageUrl == posterImageUrl &&
      other.startAt == startAt;

  @override
  int get hashCode =>
      Object.hash(id, title, venueName, isOnSale, posterImageUrl, startAt);
}
