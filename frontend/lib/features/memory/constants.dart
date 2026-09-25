import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';

/// 메모리 티켓(소장품) 기능이 쓰는 문구·치수·처리 상수.
///
/// 원래는 영역별로 흩어져 있던 여섯 장이다. 팀 규약대로 기능당 한 장으로
/// 합쳤다. 클래스 단위로 영역이 나뉘므로 고칠 자리는 이름으로 찾는다.

// ---- 컬렉션 -------------------------------------------------------------------
class CollectionText {
  static const title = '컬렉션';
  static const filterMine = '내가 만든 소장품 보기';
  static const filterAll = '모두 보기';
  static const emptyTitle = '아직 만든 소장품이 없어요';
  static const emptyBody = '공연을 골라 첫 소장품을 만들어보세요.';
  static const createLabel = '소장품 만들기';
  static const createTooltip = '새 소장품 만들기';

  /// 카탈로그를 받아 오는 동안 뼈대에 붙이는 안내. 스크린 리더가 읽는다.
  static const loading = '컬렉션을 불러오는 중이에요.';

  /// 아직 확정하지 않은 소장품 위에 뜨는 딱지.
  static const draftBadge = '임시';

  /// 미보유 칸 위에 뜨는 짧은 유도 문구.
  static const makeLabel = '만들기';

  /// 화면에는 없고 스크린리더만 읽는다 — 칸 제목 뒤에 붙는다.
  static const notOwnedLabel = '아직 만들지 않음';

  /// "모두 보기" 가 비었을 때. 카탈로그는 입장을 마친 내 티켓이라, 아직 공연에
  /// 다녀오지 않았으면 칸이 하나도 없다.
  static const catalogEmptyTitle = '아직 입장한 공연이 없어요';
  static const catalogEmptyBody = '공연에 입장하면 그 티켓이 여기에 쌓이고, 소장품을 만들 수 있어요.';

  /// 서버에만 있는 칸. 누르면 이 기기로 가져온다.
  static const restoreLabel = '가져오기';
  static const remoteLabel = '다른 기기에서 만듦';

  /// "내가 만든 소장품 보기" 위의 안내. 서버에 있는데 이 기기에 없는 것이
  /// 있을 때만 뜬다.
  static String pendingBanner(int count) => '다른 기기에서 만든 소장품 $count개가 있어요';
  static const restoreAllLabel = '모두 가져오기';
  static const swipeHint = '좌우로 돌려 다른 소장품 보기';

  /// 오르골 뒷면에 찍는 글자. 정보가 아니라 각인이다.
  static const brand = 'TIMO';
  static const backLabel = 'MEMORY TICKET';
  static String backNumber(String shortId) => 'No. $shortId';

  /// 로그인 전. 소장품은 내가 입장한 공연으로 만드는 것이라 누구인지 모르면
  /// 보여줄 것이 없다.
  static const loginTitle = '로그인하고 소장품을 만들어요';
  static const loginBody = '입장을 마친 공연으로 나만의 소장품을 만들 수 있어요.';
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

  /// Backs are already dark; only a hint more shade for depth.
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

  /// 앞면 썸네일의 어두운 프레임 두께. 홀로 선은 이 프레임과 사진의 경계에
  /// 앉는다.
  static const thumbnailFrame = 3.0;

  /// 카드 안쪽 홀로그램 하이라인([HoloFrame]). 앞면은 사진 가장자리에,
  /// 오르골 뒷면은 카드 폭·높이의 [holoFrameInset] 만큼 들어와 그린다.
  static const holoFrameStroke = 1.0;
  static const holoFrameOpacity = 0.7;
  static const holoFrameInset = 0.05;
  static const holoFrameRadius = 11.0;

  /// 오르골 뒷면([OrgelCardBack]). 비율은 카드 폭 대비이고, Alignment 는
  /// 카드 안 세로 위치다.
  static const orgelBackHairlineGap = 7.0;
  static const orgelBackHairlineAlpha = 0.045;
  static const orgelBackSilhouetteWidth = 0.56;
  static const orgelBackSilhouetteAlign = Alignment(0, -0.05);

  /// 음각: 반투명 흰 채움에 1px 어긋난 그림자·하이라이트 한 줄씩.
  static const orgelBackEmbossAlpha = 0.10;
  static const orgelBackEmbossShadowAlpha = 0.55;
  static const orgelBackEmbossHighlightAlpha = 0.12;
  static const orgelBackEmbossOffset = 1.0;
  static const orgelBackWordmarkAlign = Alignment(0, 0.49);
  static const orgelBackLabelAlign = Alignment(0, 0.62);
  static const orgelBackIdAlign = Alignment(0, 0.82);
  static const orgelBackWordmarkSize = 0.047;
  static const orgelBackLabelSize = 0.026;
  static const orgelBackIdSize = 0.034;

  /// 자간, 글자 크기 대비(em).
  static const orgelBackWordmarkTracking = 0.14;
  static const orgelBackLabelTracking = 0.28;

  /// The person drifts a little faster than the stage while swiping, which
  /// reads as depth on a flat thumbnail.
  static const personParallax = 22.0;
}

// ---- 카탈로그 -----------------------------------------------------------------
class CatalogConstants {
  /// 몰입 영상 자리를 채우는 앱 안의 데모 영상.
  ///
  /// 카탈로그 응답의 `videoUrl` 은 늘 null 이다 — 공연에 영상 컬럼이 없다
  /// (백엔드 `CollectibleConcertResponseDto`). 컬럼이 생기면 서버 값이 그대로
  /// 쓰이고 이 상수는 폴백으로만 남는다.
  static const demoVideoAsset = 'assets/videos/official_demo.mp4';
}

/// 소장품 제작·복원이 기기 문서 폴더에 쓰는 자리.
///
/// 쓰는 쪽(제작·합성·인물 분리·복원·컷아웃 수선)과 지우는 쪽
/// (`HiveTicketStore.clear`)이 같은 이름을 봐야 한다 — 어느 한쪽이 폴더를
/// 새로 만들면 여기에 더해야 로그아웃 때 함께 지워진다.
class MemoryFiles {
  MemoryFiles._();

  /// 고른 사진 원본·복원한 소장품 이미지(`photos/restored/{goodsId}`).
  static const photos = 'photos';

  /// 배경을 화면 비율로 잘라 그린 것.
  static const framedBackgrounds = 'framed_backgrounds';

  /// 인물 여러 명을 한 장으로 합친 것.
  static const composites = 'composites';

  /// 인물 한 명씩 분리한 컷아웃·깊이 맵.
  static const personLayers = 'person_layers';

  /// 컷아웃 수선 결과. 폴더 없이 문서 폴더 바로 아래에 이 접두어로 놓인다.
  static const repairPrefix = 'repair_';

  /// 로그아웃 때 통째로 지우는 폴더들.
  static const directories = [
    photos,
    framedBackgrounds,
    composites,
    personLayers,
  ];
}

/// 소장품을 서버에 올리고 되받아 올 때의 값들.
class GoodsConstants {
  /// 이미지 업로드·내려받기의 제한 시간. 공통 설정(연결 5초·수신 10초)은 JSON
  /// 응답 기준이라 수 MB 짜리 이미지 여러 장에는 짧다 — 느린 회선에서 멀쩡한
  /// 업로드가 중간에 끊긴다.
  static const transferTimeout = Duration(minutes: 3);

  /// 내 소장품 목록을 한 번에 받는 수. 서버 상한이 100 이고, 한 사람이 가진
  /// 소장품은 입장을 마친 티켓 수를 넘지 못한다.
  static const pageSize = 100;

  /// 업로드 요청 하나에 담는 파일 크기의 합 상한(24MB).
  ///
  /// 서버는 요청 하나를 30MB 까지 받는다(`spring.servlet.multipart.max-request-size`).
  /// multipart 경계·헤더와 base64 가 아닌 원 바이트라도 약간의 덧살이 붙으므로
  /// 여유를 두고 자른다. 장당 한도(10MB)는 여기서 가리지 않는다 — 파일 하나를
  /// 나눌 수는 없다.
  static const uploadBatchBytes = 24 * 1024 * 1024;

  /// 서버가 받는 인물 레이어 수 상한(백엔드 `GoodsJson.MAX_PERSON_LAYERS`).
  /// 넘겨 보내면 400 이라 확정 전에 앱이 먼저 가린다.
  static const maxPersonLayers = 2;
}

/// 소장품을 올리고 되받아 오는 동안 화면에 뜨는 문구.
///
/// 서버도 한국어 문구를 주지만 '굿즈' 라고 부르고 티켓 번호가 붙기도 한다
/// (`이미 굿즈를 만든 티켓입니다. (ticketId=12)`). 앱이 아는 이유는 앱 말로
/// 바꿔 보여주고, 모르는 이유만 서버 문구를 그대로 올린다.
class GoodsText {
  static const unreadableResponse = '소장품 정보를 읽지 못했어요.';

  /// 확정 버튼이 서버를 기다리는 동안.
  static const uploading = '올리는 중…';

  static const alreadyExists = '이 티켓으로 만든 소장품이 이미 있어요.';
  static const ticketNotOwned = '지금 내가 가진 티켓이 아니에요.';
  static const ticketNotUsed = '입장을 마친 티켓으로만 소장품을 만들 수 있어요.';
  static const imageDeleted = '올려 둔 사진이 지워졌어요. 다시 만든 뒤 확정해주세요.';
  static const invalidLayers = '인물은 2명까지만 담을 수 있어요.';

  /// 올리기 전에 앱이 먼저 가리는 것들.
  static const missingBackground = '배경 사진을 찾을 수 없어 확정하지 못했어요.';

  /// 서버에 있는 소장품을 이 기기로 가져올 때.
  static const restoring = '소장품을 가져오는 중이에요';
  static const restoreFailed = '소장품을 가져오지 못했어요. 다시 시도해주세요.';

  /// 복원한 소장품의 처리 정보 첫 줄. 이 기기에서 만든 것과 구분된다.
  static const restoredNote = '서버에 저장된 소장품을 이 기기로 가져왔어요';
}

// ---- 제작 --------------------------------------------------------------------
class CreatorText {
  static const totalSteps = 6;
  static const appBarTitle = '공연 추억 만들기';

  /// 공연 목록을 받아 오는 동안 뼈대에 붙이는 안내. 스크린 리더가 읽는다.
  static const loadingConcerts = '공연을 불러오는 중이에요.';
  static const brand = 'TIMO';
  static const titles = [
    '소장품을 만들 공연을\n선택해주세요',
    '배경에 쓰일\n사진을 골라주세요!',
    '아티스트의 사진을\n선택해주세요',
    '더 추가하고 싶은 인물 사진이\n있다면 추가해도 좋아요!',
    '인물을\n조정해주세요',
    '추가하고 싶은\n이펙트가 있나요?',
  ];
  static const subtitles = [
    '그날의 순간을 나만의 티켓으로 간직해요.',
    '공연 영상과도 이어지니 신중히 선택해야 해요.',
    '마음에 드는 사진을 선택하면 돼요.',
    '원하는 사진을 직접 고를 수 있어요.',
    '인물을 눌러 옮기고, 크기와 입체감을 정할 수 있어요.',
    '마음에 드는 걸 골라보세요.',
  ];

  /// Buttons.
  static const concertAction = '이 공연으로 만들기';
  static const nextLabel = '다음으로';
  static const skipLabel = '건너뛰기';
  static const finishLabel = '완료하기';
  static const retryLabel = '다시 만들기';
  static const backTooltip = '이전 단계';

  /// 만들 수 있는 공연이 하나도 없을 때. 티켓 한 장에 소장품은 하나뿐이라
  /// 이미 만든 공연은 목록에서 빠진다.
  static const noConcertsTitle = '만들 수 있는 공연이 없어요';
  static const noConcertsBody = '입장을 마친 공연으로 만들 수 있고, 한 공연에 하나씩만 만들어요.';

  /// Photo tiles. 데모 소재는 앱에 든 것이고, 공연 소재는 서버가 그 공연에
  /// 붙여 둔 것이다(`/concerts/{id}/kit`).
  static const stageLabel = '데모 무대';
  static const illustrationLabel = '데모 일러스트';
  static const analysisSampleLabel = '분석 테스트 사진';
  static const kitStageLabel = '공연 무대';
  static const kitPersonLabel = '공연 인물';
  static const kitLoading = '공연 소재를 불러오는 중이에요';
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

  /// 누끼는 됐는데 얼굴도 자세도 못 찾았을 때. 사람이 아닌 사진일 수 있다는
  /// 확인일 뿐이라 막지 않는다 — 옆모습·역광이면 사람이어도 여기 걸린다.
  static const noPersonTitle = '사람이 잘 보이지 않는 사진 같아요';
  static const noPersonBody = '얼굴과 자세를 찾지 못했어요. 이대로 진행하면 입체감과 자동 배치가 단순해져요.';

  /// Errors.
  static const saveFailed = '소장품을 저장하지 못했어요. 다시 시도해주세요.';
  static const kitFailed = '공연 소재를 불러오지 못했어요.';
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

  /// 인물 단계에서 고른 누끼를 확인만 하는 칸.
  static const personPreviewHeight = 170.0;
  static const giftSize = 210.0;

  /// 건너뛰기. 주 버튼(52)보다 한 단 낮아 둘의 무게가 갈린다.
  static const skipButtonHeight = 46.0;

  /// 제작 클립. 원본 비율 그대로 두되, 선물 상자가 서던 자리보다 넓게 쓴다.
  static const clipAspect = 16 / 9;
  static const clipWidthFactor = 1.6;

  /// 만드는 장면이 끝나고 완성된 선물이 드러나기 시작하는 지점. 제작 중에는
  /// 여기서 앞으로 되감아, 완성을 미리 보여주지 않는다.
  static const clipMakingEnd = Duration(seconds: 6, milliseconds: 500);
}

// ---- 공유(싸피스타그램) --------------------------------------------------------

/// 소장품을 스토리로 올리는 흉내를 내는 화면의 문구·치수.
///
/// 진짜 인스타그램을 켜지 않는다. 상표를 쓰지 않으려고 이름도 로고도 우리
/// 것으로 짓는다. 실제 공유 연동은 이 화면이 하는 일이 아니다.
class ShareText {
  static const brand = '싸피스타그램';
  static const title = '스토리로 공유';
  static const account = '내 스토리';
  static const justNow = '방금';
  static const tiltOption = '받는 사람도 기울여 볼 수 있게';
  static const tiltOptionBody = '스토리를 보는 사람이 폰을 기울이면 카드가 따라 움직여요.';
  static const post = '내 스토리에 공유';
  static const uploading = '올리는 중…';
  static const posted = '스토리에 공유했어요';
  static const tiltHint = '폰을 기울여 보세요';
  static const closeTooltip = '스토리 닫기';
  static const messageHint = '메시지 보내기';
  static const shareTooltip = '스토리로 공유';
}

class ShareLayout {
  /// 세로 스토리 한 장의 비율.
  static const storyAspect = 9 / 16;

  static const uploadDuration = Duration(milliseconds: 1700);

  /// 올라간 스토리가 저절로 흘러가는 시간. 끝나도 닫지는 않는다 — 보는 도중에
  /// 화면이 사라지면 기울여 보던 사람이 놀란다.
  static const storyDuration = Duration(seconds: 15);
}

// ---- 뷰어 --------------------------------------------------------------------

/// 소장품을 여는 화면의 문구.
class ViewerText {
  /// 확정 전 한 줄. 상자와 제목까지 두면 카드보다 안내가 커진다.
  static const draftNote = '임시 저장 · 이 기기에만 있어요';
  static const editLabel = '다시 만들기';
  static const confirmLabel = '확정하기';
  static const confirmTitle = '이대로 확정할까요?';
  static const confirmMessage = '확정하면 서버에 올라가고, 그 뒤로는 고치거나 지울 수 없어요.';
  static const confirmCancel = '더 볼게요';
  static const confirmOk = '확정';
  static const confirmed = '소장품을 확정했어요';
  static const confirmFailed = '확정하지 못했어요. 다시 시도해주세요.';

  /// 기울임이 켜져 있을 때 버튼이 말하는 것 — 누르면 꺼진다.
  static const tiltOnTooltip = '기울임 효과 끄기';
  static const tiltOffTooltip = '기울임 효과 켜기';

  /// 조작법 안내. 처음 열 때 한 번 뜨고, 앱바의 ? 로 다시 볼 수 있다.
  static const guideTooltip = '조작법 보기';
  static const guideTitle = '이렇게 감상해요';
  static const guideSwipe = '좌우로 밀어 뒤집기';
  static const guideSwipeBody = '카드를 옆으로 밀면 뒷면의 티켓 정보가 나와요';
  static const guideHold = '길게 눌러 영상 보기';
  static const guideHoldBody = '카드를 꾹 누르고 있으면 그날의 영상이 흘러요';
  static const guideOk = '알겠어요';

  /// 디버그 빌드에만 남는 개발용 버튼. 사용자가 볼 이유가 없는 처리 내역이다.
  static const processingInfo = '처리 정보';
}

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
