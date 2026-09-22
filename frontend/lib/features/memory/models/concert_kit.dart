import '../constants.dart';

/// 소장품을 만들 때 고를 수 있는 소재 한 장 — 배경이거나 인물이다.
///
/// [source] 는 서버 주소이거나 앱 에셋 경로다. 서버가 소재를 갖고 있지 않은
/// 공연이 정상이라(백엔드 `ConcertKitApi`) 그때는 앱에 든 데모 소재로 채우고,
/// 두 출처를 같은 타일로 그린다. 어느 쪽인지는 [isAsset] 이 가른다 —
/// 에셋은 번들에서 복사하고 주소는 내려받는다.
class KitAsset {
  const KitAsset(this.source);

  final String source;

  bool get isAsset => source.startsWith('assets/');
}

/// 공연 하나의 소재 묶음.
class ConcertKit {
  const ConcertKit({required this.backgrounds, required this.people});

  final List<KitAsset> backgrounds, people;

  /// 앱에 든 데모 소재. 서버 소재가 없거나 받지 못했을 때 그 자리를 채운다.
  static final demo = ConcertKit(
    backgrounds: [for (final path in CreatorText.backgrounds) KitAsset(path)],
    people: [for (final path in CreatorText.people) KitAsset(path)],
  );

  /// 서버 소재가 비어 있는 쪽만 데모로 채운 묶음. 배경은 준비했는데 인물은
  /// 아직인 공연이 있을 수 있어 통째로가 아니라 쪽마다 따진다.
  ConcertKit orDemo() => ConcertKit(
    backgrounds: backgrounds.isEmpty ? demo.backgrounds : backgrounds,
    people: people.isEmpty ? demo.people : people,
  );
}
