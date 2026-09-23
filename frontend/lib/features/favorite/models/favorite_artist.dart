import 'package:flutter/foundation.dart';

/// 찜한 아티스트 한 명. 기기에 남기는 스냅샷이다. 아직 서버 id 가 없어
/// **이름**으로 같은 사람인지 가른다. id 가 생기면 그때 바꾼다.
@immutable
class FavoriteArtist {
  const FavoriteArtist({required this.name, this.profileImageUrl});

  factory FavoriteArtist.fromJson(Map<String, dynamic> json) => FavoriteArtist(
    name: json['name'] as String,
    profileImageUrl: json['profileImageUrl'] as String?,
  );

  final String name;

  /// 프로필 사진 주소. 없으면 마스코트 얼굴로 대체한다.
  final String? profileImageUrl;

  Map<String, dynamic> toJson() => {
    'name': name,
    'profileImageUrl': profileImageUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is FavoriteArtist &&
      other.name == name &&
      other.profileImageUrl == profileImageUrl;

  @override
  int get hashCode => Object.hash(name, profileImageUrl);
}
