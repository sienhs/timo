import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// 찜한 공연 한 건. 카드를 그릴 만큼만 담은 공연 요약이다. 목록을 열 때는
/// 서버 응답에서 [FavoriteShow.fromConcertSummaryJson] 으로 만들고, 하트를 누른
/// 순간에는 그 화면의 공연을 바꿔 만든다(목록을 다시 받으면 서버 것으로 덮인다).
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

  /// 서버의 공연 요약(`ConcertSummaryResponseDto`) 한 건을 읽는다. 포스터 주소는
  /// 저장소 key 그대로 두고, 절대 주소로 바꾸는 일은 그리는 쪽이 맡는다.
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

  /// 아직 살 수 있는 공연의 상태. 백엔드 `ConcertStatus` 의 상수명이다. 필터가
  /// '판매 중 / 판매 종료' 둘뿐이라 오픈 예정도 판매 중으로 친다.
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
