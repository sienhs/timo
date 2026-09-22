import 'package:flutter/material.dart';
import 'package:timo/features/memory/data/goods_api.dart';
import 'package:timo/features/memory/data/memory_concert_api.dart';
import 'package:timo/features/memory/data/ticket_store.dart';
import 'package:timo/features/memory/state/creation_job.dart';
import 'package:timo/features/memory/state/creation_job_scope.dart';
import 'package:timo/features/memory/state/goods_api_scope.dart';
import 'package:timo/features/memory/state/memory_concert_api_scope.dart';
import 'package:timo/features/memory/state/ticket_store_scope.dart';

/// 메모리 티켓 화면 하나를 단독으로 띄울 때 필요한 스코프 묶음.
///
/// 앱에서는 `App` 이 이 셋을 내려준다. 화면 단위 테스트는 App 전체를 띄우지
/// 않으므로 같은 조립을 여기서 한 번만 해 둔다 — 테스트마다 세 겹을 다시 쌓으면
/// 스코프가 하나 늘 때마다 테스트를 전부 고쳐야 한다.
Widget withMemoryScopes(
  Widget child, {
  TicketStore? store,
  MemoryConcertApi? concertApi,
  GoodsApi? goodsApi,
}) {
  final ticketStore = store ?? InMemoryTicketStore();
  return TicketStoreScope(
    store: ticketStore,
    child: MemoryConcertApiScope(
      api: concertApi ?? MockMemoryConcertApi(),
      child: GoodsApiScope(
        api: goodsApi ?? MockGoodsApi(),
        child: CreationJobScope(
          job: CreationJob(store: ticketStore),
          child: child,
        ),
      ),
    ),
  );
}
