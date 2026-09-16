import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/memory_ticket.dart';

/// 만든 소장품을 두는 곳.
///
/// 서버가 아니라 기기다. 소장품은 사진·깊이맵·컷아웃까지 기기 안에서 만들어지고
/// 그 결과가 가리키는 것도 전부 기기 파일이라, 아직 서버에 올릴 것이 없다.
/// 서버 저장(`goods` 테이블)이 붙으면 그때 올린다.
///
/// [ChangeNotifier] 인 이유는 제작이 화면 밖에서 끝나기 때문이다. 목록 화면은
/// 스스로 다시 읽을 계기가 없어서, 저장·삭제가 일어난 쪽에서 알려 줘야 목록이
/// 따라온다. 그 알림을 `TicketStoreScope` 가 화면으로 나른다.
abstract class TicketStore extends ChangeNotifier {
  /// 최근에 만든 것이 앞. 목록 맨 앞 카드가 방금 만든 소장품이 된다.
  List<MemoryTicket> readAll();

  Future<void> save(MemoryTicket ticket);

  Future<void> delete(String id);
}

/// 기기에 남는 저장소. 앱이 쓰는 구현이다.
class HiveTicketStore extends TicketStore {
  HiveTicketStore(this.box);

  static const boxName = 'timo_memory_v1';

  final Box<String> box;

  @override
  List<MemoryTicket> readAll() => box.values
      .map((e) => MemoryTicket.fromJson(jsonDecode(e) as Map<String, dynamic>))
      .toList()
      .reversed
      .toList();

  @override
  Future<void> save(MemoryTicket ticket) async {
    await box.put(ticket.ticketId, jsonEncode(ticket.toJson()));
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    await box.delete(id);
    notifyListeners();
  }
}

/// 앱을 끄면 사라지는 저장소.
///
/// 위젯 테스트가 쓰고, 기기 저장소를 열지 못한 실행(main 의 Hive 실패)에서도
/// 이걸로 시작한다. 소장품 하나 때문에 앱 전체가 안 켜지는 것보다, 이번 실행에만
/// 남는 컬렉션을 보여 주는 쪽이 낫다.
class InMemoryTicketStore extends TicketStore {
  final _tickets = <String, MemoryTicket>{};

  @override
  List<MemoryTicket> readAll() => _tickets.values.toList().reversed.toList();

  @override
  Future<void> save(MemoryTicket ticket) async {
    _tickets[ticket.ticketId] = ticket;
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    _tickets.remove(id);
    notifyListeners();
  }
}
