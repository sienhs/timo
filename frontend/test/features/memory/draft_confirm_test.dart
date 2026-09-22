import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/goods_api.dart';
import 'package:timo/features/memory/data/ticket_store.dart';
import 'package:timo/features/memory/models/goods_record.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/memory/screens/memory_ticket_screen.dart';
import 'package:timo/features/memory/state/goods_api_scope.dart';
import 'package:timo/features/memory/state/ticket_store_scope.dart';
import 'package:timo/features/memory/state/tilt_setting_scope.dart';
import 'package:timo/features/memory/state/viewer_guide_scope.dart';
import 'package:timo/features/memory/data/tilt_setting.dart';
import 'package:timo/features/memory/data/viewer_guide_setting.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/widgets/collection/ticket_thumbnail.dart';

const _draft = MemoryTicket(
  ticketId: 'ticket-1024',
  concertId: 'concert-1024',
  backgroundPath: '/none/background.png',
  personCompositePath: null,
  effectType: '효과 없음',
  videoId: 'concert-1024-main',
  videoUrl: '',
  details: {'공연명': '빛으로 남은 밤', '날짜': '2026.09.26'},
  depthLayers: [],
  demoDepth: false,
);

Widget _viewer(TicketStore store, MemoryTicket ticket, {GoodsApi? goodsApi}) =>
    MaterialApp(
      theme: timoDarkTheme(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: TicketStoreScope(
          store: store,
          child: GoodsApiScope(
            api: goodsApi ?? MockGoodsApi(),
            child: TiltSettingScope(
              setting: _tiltOff(),
              // 조작법 안내는 이미 본 것으로 둔다. 안 그러면 안내가 확정 버튼을
              // 가려 이 테스트가 보려는 것을 못 누른다.
              child: ViewerGuideScope(
                setting: ViewerGuideSetting(
                  InMemoryViewerGuideStore(true),
                  alreadySeen: true,
                ),
                child: MemoryTicketScreen(ticket: ticket),
              ),
            ),
          ),
        ),
      ),
    );

/// 기울임을 끈 설정. 켜 두면 카드가 센서 채널을 여는데, `runAsync` 안에서는
/// 플러그인 없음 예외가 진짜로 터져 테스트가 실패한다. 저장은 메모리라 즉시다.
TiltSetting _tiltOff() => TiltSetting(InMemoryTiltSettingStore())..toggle();

/// 확정은 배경 사진을 실제로 올리므로, 파일이 있어야 거기까지 간다.
Future<MemoryTicket> _draftWithBackground() async {
  final directory = await Directory.systemTemp.createTemp('timo_draft');
  final background = File('${directory.path}/background.png');
  await background.writeAsBytes(const [0x89, 0x50, 0x4E, 0x47]);
  return _draft.copyWith(backgroundPath: background.path);
}

void main() {
  test('새로 만든 소장품은 확정 전이고, 저장되면 그대로 읽힌다', () {
    expect(_draft.confirmed, isFalse);
    expect(MemoryTicket.fromJson(_draft.toJson()).confirmed, isFalse);
  });

  test('확정 개념이 생기기 전에 저장된 것은 확정본으로 읽는다', () {
    final old = _draft.toJson()..remove('confirmed');
    expect(MemoryTicket.fromJson(old).confirmed, isTrue);
  });

  testWidgets('확정 전 소장품에는 임시 딱지가 붙는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: timoDarkTheme(),
        home: Center(
          child: SizedBox(
            width: 200,
            height: 300,
            child: TicketThumbnail(ticket: _draft),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(CollectionText.draftBadge), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: timoDarkTheme(),
        home: Center(
          child: SizedBox(
            width: 200,
            height: 300,
            child: TicketThumbnail(ticket: _draft.copyWith(confirmed: true)),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(CollectionText.draftBadge), findsNothing);
  });

  testWidgets('확정하면 서버에 올라가고 저장되고 확정 줄이 사라진다', (tester) async {
    final store = InMemoryTicketStore();
    // 파일을 만들고 읽는 진짜 I/O 는 fake async 안에서 끝나지 않는다.
    final draft = (await tester.runAsync(_draftWithBackground))!;
    final goodsApi = MockGoodsApi();
    await store.save(draft);
    await tester.pumpWidget(_viewer(store, draft, goodsApi: goodsApi));
    await tester.pump();

    expect(find.text(ViewerText.draftNote), findsOneWidget);
    // 확정 전에는 내보낼 수 없다.
    expect(find.byTooltip(ShareText.shareTooltip), findsNothing);

    // 올리기 전에 배경 파일이 있는지 실제로 본다 — 그 I/O 가 끝나려면 진짜
    // 시간이 흘러야 한다.
    await tester.runAsync(() async {
      await tester.tap(find.text(ViewerText.confirmLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(ViewerText.confirmOk));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (store.readAll().single.confirmed) break;
      }
      await tester.pump();
    });

    final saved = store.readAll().single;
    expect(saved.confirmed, isTrue);
    // 서버가 매긴 번호까지 받아 두어야 나중에 상세를 다시 받아 올 수 있다.
    expect(saved.goodsId, isNotNull);
    expect(await goodsApi.fetchMyGoods(), hasLength(1));
    expect(find.text(ViewerText.draftNote), findsNothing);
    expect(find.byTooltip(ShareText.shareTooltip), findsOneWidget);
  });

  testWidgets('서버가 거절하면 저장하지 않고 이유를 알린다', (tester) async {
    final store = InMemoryTicketStore();
    final draft = (await tester.runAsync(_draftWithBackground))!;
    await store.save(draft);
    await tester.pumpWidget(
      _viewer(store, draft, goodsApi: _RejectingGoodsApi()),
    );
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text(ViewerText.confirmLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(ViewerText.confirmOk));
      // 파일 확인은 진짜 I/O 라 걸리는 시간이 기기마다 다르다. 안내가 뜰
      // 때까지 잠깐씩 기다린다.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find.text(GoodsText.alreadyExists).evaluate().isNotEmpty) break;
      }
    });

    // 서버가 받지 않았으면 확정도 아니다. 확정해 두면 다시 만들 수도 없다.
    expect(store.readAll().single.confirmed, isFalse);
    expect(find.text(GoodsText.alreadyExists), findsOneWidget);
  });

  testWidgets('확정한 소장품에는 확정 줄이 없다', (tester) async {
    final confirmed = _draft.copyWith(confirmed: true);
    await tester.pumpWidget(_viewer(InMemoryTicketStore(), confirmed));
    await tester.pump();

    expect(find.text(ViewerText.draftNote), findsNothing);
    expect(find.text(ViewerText.confirmLabel), findsNothing);
  });
}

/// 이 티켓으로 이미 만들었다며 거절하는 서버.
class _RejectingGoodsApi extends MockGoodsApi {
  @override
  Future<GoodsDetail> create({
    required String ticketId,
    required Map<String, dynamic> body,
  }) async => throw const ApiException(
    '이미 굿즈를 만든 티켓입니다. (ticketId=1)',
    status: 409,
    exceptionName: 'GoodsAlreadyExistsException',
  );
}
