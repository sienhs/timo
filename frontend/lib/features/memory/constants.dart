import 'package:flutter/physics.dart';
import 'dart:ui';

/// 메모리 티켓(소장품) 기능이 쓰는 문구·치수·처리 상수.
///
/// 원래는 영역별로 흩어져 있던 여섯 장이다. 팀 규약대로 기능당 한 장으로
/// 합쳤다. 클래스 단위로 영역이 나뉘므로 고칠 자리는 이름으로 찾는다.

// ---- 컬렉션 -------------------------------------------------------------------
class CollectionText {
  static const title = '컬렉션';
  static const filterMine = '내가 가진 티켓만 보기';
  static const filterAll = '모두 보기';
  static const emptyTitle = '아직 가진 티켓이 없어요';
  static const emptyBody = '공연을 골라 첫 소장품을 만들어보세요.';
  static const createLabel = '소장품 만들기';
  static const createTooltip = '새 소장품 만들기';
  static const deleteTooltip = '소장품 삭제';
  static const notOwnedLabel = '아직 없는 소장품';
  static const swipeHint = '좌우로 돌려 다른 소장품 보기';
  static String ownedCount(int n) => '$n장 보유';
}

class CollectionLayout {
  static const columns = 2;
  static const gridSpacing = 14.0;
  static const pagePadding = 22.0;

  /// Same shape as the viewer card so thumbnails match what opens.
  static const cardAspect = ViewerConstants.cardAspect;

  /// 오르골: tickets stand on a ring around a vertical axis and the whole
  /// platform turns. Fewer than [orgelMinSlots] tickets still spread over a
  /// ring of that many slots so nothing hides directly behind the front card.
  static const orgelMinSlots = 6;
  static const orgelPerspective = 0.0011;
  static const orgelCardHeightFactor = 0.72;
  static const orgelCardWidthFactor = 0.64;

  /// Extra scale on the card facing the viewer.
  static const orgelFrontBoost = 0.07;

  /// Wider than the screen on purpose: side cards may run off the edges.
  static const orgelRadiusFactor = 1.0;
  static const orgelRise = 0.0;
  static const orgelDepthDim = 0.6;

  /// White backs stay white; only a hint of shade for depth.
  static const orgelBackDim = 0.08;
  static const orgelFlingLookahead = 0.18;

  /// Settle spring: carries the release velocity in and lands with a small
  /// overshoot, so a spin feels like a real platform coming to rest.
  static const orgelSpring = SpringDescription(
    mass: 1,
    stiffness: 120,
    damping: 13,
  );
  static const orgelPlatformSqueeze = 0.2;

  /// Space between the platform and the concert caption.
  static const orgelCaptionGap = 30.0;

  /// The person drifts a little faster than the stage while swiping, which
  /// reads as depth on a flat thumbnail.
  static const personParallax = 22.0;
}

// ---- 제작 --------------------------------------------------------------------
class CreatorText {
  static const totalSteps = 5;
  static const appBarTitle = 'NFT 소장품 만들기';
  static const brand = 'TIMO';
  static const titles = [
    '소장품을 만들 공연을\n선택해주세요',
    '배경에 쓰일\n사진을 골라주세요!',
    '아티스트의 사진을\n선택해주세요',
    '더 추가하고 싶은 인물 사진이\n있다면 추가해도 좋아요!',
    '추가하고 싶은\n이펙트가 있나요?',
  ];
  static const subtitles = [
    '그날의 순간을 나만의 티켓으로 간직해요.',
    '공연 영상과도 이어지니 신중히 선택해야 해요.',
    '마음에 드는 사진을 선택하면 돼요.',
    '원하는 사진을 직접 고를 수 있어요.',
    '마음에 드는 걸 골라보세요.',
  ];

  /// Buttons.
  static const concertAction = 'NFT 소장품 만들기';
  static const nextLabel = '다음으로';
  static const skipLabel = '건너뛰기';
  static const finishLabel = '완료하기';
  static const retryLabel = '다시 만들기';
  static const backTooltip = '이전 단계';

  /// Photo tiles.
  static const stageLabel = '데모 무대';
  static const illustrationLabel = '데모 일러스트';
  static const analysisSampleLabel = '분석 테스트 사진';
  static const addPhotoLabel = '사진 추가';

  /// 사진 출처 시트. "+" 타일은 갤러리와 카메라 둘 중 하나를 고르게 한다.
  static const photoSourceTitle = '사진을 어디서 가져올까요?';
  static const galleryLabel = '갤러리에서 선택';
  static const cameraLabel = '카메라로 촬영';
  static const backgrounds = [
    'assets/demo/stage_blue.png',
    'assets/demo/stage_gold.png',
    'assets/demo/stage_pink.png',
  ];
  static const people = [
    'assets/demo/person_a.png',
    'assets/demo/person_b.png',
    'assets/demo/pose_test.jpg',
  ];

  /// Short per-photo work shown inline while a picked photo is analysed.
  static const processing = [
    '사진을 처리하고 있어요',
    '배경을 준비하고 있어요',
    '인물 누끼와 자세, 입체감을 준비하고 있어요',
    '깊이 분석과 인물 합성을 진행하고 있어요',
  ];

  /// The "제작중" stage. Generation keeps running if the user leaves; the
  /// completion banner brings them back.
  static const processingTitle = '소장품을 만드는 중이에요';
  static const processingBody = '기다리는 동안 앱을 둘러보세요\n완성되면 알림으로 알려드릴게요';
  static const doneTitle = '소장품이 완성되었어요!';
  static const doneBody = '완료하기를 눌러 완성된 소장품을 확인해보세요.';
  static const failedTitle = '소장품을 만들지 못했어요';
  static const failedBody = '사진을 다시 확인한 뒤 한 번 더 시도해주세요.';
  static const onDeviceNote = '사진은 기기 안에서만 처리돼요';

  /// In-app notification shown when the job finishes anywhere in the app.
  static const notificationTitle = '소장품 제작이 완료되었어요!';
  static const notificationBody = '완성된 소장품을 확인해볼까요?';
  static const notificationTime = 'now';

  /// Errors.
  static const saveFailed = '소장품을 저장하지 못했어요. 다시 시도해주세요.';
  static const photoFailed = '사진 처리에 실패했어요. 다시 선택해주세요.';
  static const permissionFailed = '사진 접근 권한을 확인한 뒤 다시 선택해주세요.';
  static const cameraFailed = '카메라를 열 수 없어요. 카메라 권한을 확인한 뒤 다시 시도해주세요.';
  static const lostPhoto = '사진 선택 중 앱이 다시 시작됐어요. 제작 단계에서 사진을 다시 선택해주세요.';
}

class CreatorLayout {
  static const pagePadding = 22.0;
  static const gridSpacing = 14.0;
  static const photoTileAspect = 0.7;
  static const effectTileAspect = 0.7;
  static const previewHeight = 220.0;
  static const giftSize = 210.0;
}

// ---- 뷰어 --------------------------------------------------------------------
class ViewerConstants {
  /// Card shape used by the photo editor and saved background.
  static const cardAspect = 9 / 14;

  /// Translation multipliers per layer: backplate, three depth bands,
  /// person composite, effects. Nearer layers travel further.
  static const parallax = [0.3, 0.7, 1.1, 1.5, 2.0];

  /// The person stays centred on the card with a fixed size and soft shadow.
  static const personScale = 1.035;
  static const personShadowOffset = Offset(0, 22);
  static const personShadowBlur = 16.0;
  static const personShadowOpacity = 0.68;

  /// Effect layers move independently around the stationary person.
  static const behindEffectParallax = 1.3;
  static const frontEffectParallax = 3.2;
  static const flipDuration = Duration(milliseconds: 680);

  /// Tilt is kept in "tilt units" clamped to ±maxTilt; everything else is
  /// derived from it so one number tunes the whole card.
  static const maxTilt = 12.0;
  static const perspective = 0.0012;
  static const tiltAngle = 0.0026;
  static const dragGain = 0.15;
  static const gyroGain = 2.0;
  static const gyroDecayPerSecond = 0.15;

  /// Accelerometer tilt: m/s² deviation from the resting pose → tilt units,
  /// with a fast smoothing on the reading and a slow one on the baseline.
  static const gravityGain = 6.0;
  static const gravitySmoothing = 0.25;
  static const gravityRestSmoothing = 0.006;

  /// Depth shader: uv shift for the nearest pixels at maxTilt, and the
  /// overscan zoom that hides displaced edges.
  /// Body-part layers: how much further a whole layer slides than the
  /// single-map shader would, and how much relief stays inside a layer.
  static const personLayerGain = 3.0;
  static const personReliefGain = 0.5;

  static const depthShift = 0.055;
  static const depthZoom = 1.10;

  /// Subtle foil keeps the photo readable, including while tilting.
  static const holoIdle = 0.06;
  static const holoActive = 0.18;
  static const shadowLift = 26.0;
  static const liftScale = 0.03;
  static const foregroundInset = 26.0;

  /// Frame used for effects when motion is reduced (a lively still).
  static const staticEffectTime = 1.7;
}

// ---- 몰입 영상 -----------------------------------------------------------------
class ImmersiveConstants {
  /// Hold length: light gathers into the finger over this time.
  static const hold = Duration(milliseconds: 560);

  /// Card → fullscreen expansion (also the graceful exit length).
  static const enter = Duration(milliseconds: 650);

  /// Quick exit used when the user cancels (tap, drag, background, no video).
  static const leave = Duration(milliseconds: 340);
  static const moveTolerance = 10.0;
  static const flipThreshold = 85.0;

  /// Thin progress line shown while the released video plays to its end.
  static const lingerBarHeight = 3.0;

  /// How dark the rest of the screen goes behind the fullscreen video.
  static const scrimOpacity = 0.96;
}

// ---- 인물 깊이 레이어 -------------------------------------------------------------
/// Tuning for splitting a person's depth map into body-part layers.
/// Distances are fractions of the shoulder width measured in the cutout.
class PersonLayeringConstants {
  /// Long side of the grid the assignment runs on. The part map is sampled
  /// as a texture, so it never needs the cutout's full resolution.
  static const workingLongSide = 320;

  /// MediaPipe visibility below this means the landmark is a guess.
  static const visibleLandmark = 0.5;

  /// Landmarks slightly outside the cutout still describe a real limb.
  static const landmarkMargin = 0.1;

  /// Same thresholds the native pipeline uses for the person mask.
  static const foregroundAlpha = 12;

  /// A working pixel is inside the person when its averaged alpha exceeds this.
  static const insideAlpha = 32;

  /// Weight of the depth term against the geometric term. A depth gap of
  /// 0.35 (of the person's range) costs as much as standing one falloff away.
  static const depthWeight = 8.0;

  /// Parts and layers smaller than this are folded into their neighbours.
  static const minPartPixels = 30;
  static const minLayerShare = 0.02;

  /// Layers closer than this (0–255 depth units) merge; they would not
  /// separate visibly.
  static const minLayerDepthGap = 15;
  static const maxLayers = 4;

  /// Shoulder width estimates when the shoulders themselves are hidden.
  static const shoulderFromEars = 2.5;
  static const shoulderFromWidth = 0.35;
  static const minShoulderFraction = 0.15;

  /// Head: circle around the visible face points, extended upward for hair.
  static const headRadiusFromEars = 0.75;
  static const headRadius = 0.30;
  static const headCore = 0.75;
  static const headFalloff = 0.6;
  static const hairLift = 0.6;

  /// Torso: shoulder–hip quad, or a box of this many shoulder widths down.
  static const torsoLength = 1.3;
  static const torsoFalloff = 0.6;

  /// Inside the torso quad everything costs this much, so limbs and the head
  /// win their own core and the torso keeps whatever is left.
  static const torsoBias = 0.1;

  /// Arms and hands: capsules around the landmark segments.
  static const armCore = 0.09;
  static const armFalloff = 0.14;

  /// The forearm capsule ends this far from elbow to wrist; the rest is hand.
  static const forearmReach = 0.7;
  static const handCore = 0.10;
  static const handFalloff = 0.12;

  /// Legs: hip–knee–ankle capsules, so a full-body photo does not fold the
  /// nearest limbs into the torso.
  static const legCore = 0.16;
  static const legFalloff = 0.22;

  /// Edge softening and how far weights are pushed past the silhouette so
  /// linear texture sampling never fades toward "no layer" at the outline.
  static const featherPasses = 1;
  static const dilatePasses = 3;
}
