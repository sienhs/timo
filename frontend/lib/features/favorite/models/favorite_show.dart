import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// 찜한 공연 한 건. 찜하는 순간의 공연 정보를 그대로 남긴 **스냅샷**이다.
///
/// 찜 API 가 아직 없어 기기에만 남긴다. 그래서 공연 번호만 두고 목록을 열 때
/// 서버에 다시 묻는 대신, 카드를 그릴 만큼의 정보를 함께 적어 둔다 — 서버 없이
/// 목록이 떠야 하기 때문이다. 판매 상태([isOnSale])도 찜한 시점의 값이라
/// 매진·종료가 되어도 따라오지 않는다. 서버 저장이 붙으면 이 모델은 공연
/// 번호만 남기고 나머지는 응답에서 받는 쪽으로 바뀐다.
///
/// 홈의 `ShowSummary`·상세의 `ShowDetail` 을 그대로 저장하지 않는 이유는 둘
/// 중 어느 화면에서 찜했든 같은 모양으로 남아야 해서다. 변환은 각 도메인이
/// 맡는다(`features/home/utils/favorite_targets.dart` 등).
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

  factory FavoriteShow.fromJson(Map<String, dynamic> json) => FavoriteShow(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    venueName: json['venueName'] as String,
    isOnSale: json['isOnSale'] as bool? ?? false,
    posterImageUrl: json['posterImageUrl'] as String?,
    startAt: switch (json['startAt']) {
      final String raw => DateTime.parse(raw),
      _ => null,
    },
  );

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'venueName': venueName,
    'isOnSale': isOnSale,
    'posterImageUrl': posterImageUrl,
    'startAt': startAt?.toIso8601String(),
  };

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
