import 'package:flutter/material.dart';

/// 카테고리 화면의 장르 한 칸. 이름과 순서는 서버의 공연 장르(`ConcertGenre`)를
/// 따른다. [isAvailable] 은 그 장르의 공연이 실제로 있는지다 — MVP 는 콘서트만
/// 다루므로 콘서트만 참이다.
@immutable
class ShowCategory {
  const ShowCategory({
    required this.label,
    required this.icon,
    this.isAvailable = false,
  });

  final String label;
  final IconData icon;
  final bool isAvailable;
}

/// 카테고리 격자. 서버 장르 순서와 같고, 공연이 있는 콘서트가 첫 칸이다.
const showCategories = <ShowCategory>[
  ShowCategory(label: '콘서트', icon: Icons.mic_external_on, isAvailable: true),
  ShowCategory(label: '뮤지컬', icon: Icons.theater_comedy),
  ShowCategory(label: '연극', icon: Icons.theaters),
  ShowCategory(label: '클래식', icon: Icons.piano),
  ShowCategory(label: '페스티벌', icon: Icons.festival),
  ShowCategory(label: '스포츠', icon: Icons.sports_soccer),
];
