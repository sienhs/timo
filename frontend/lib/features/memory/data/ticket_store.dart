import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
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
///
/// **소장품은 계정의 것이지 기기의 것이 아니다.** 그런데 저장소는 기기에 하나라,
/// 로그아웃할 때 [clear] 로 전부 비운다. 안 비우면 다음에 로그인한 다른 사람이
/// 앞사람 소장품과 사진을 컬렉션에서 그대로 본다. 확정한 것은 서버에 있어 다시
/// 받으면 되고, 확정 전 임시본은 로그아웃과 함께 사라진다(찜 공연과 같다).
abstract class TicketStore extends ChangeNotifier {
  /// 최근에 만든 것이 앞. 목록 맨 앞 카드가 방금 만든 소장품이 된다.
  List<MemoryTicket> readAll();

  Future<void> save(MemoryTicket ticket);

  Future<void> delete(String id);

  /// 소장품과 그것이 가리키던 기기 파일을 전부 지운다. 로그아웃할 때 부른다.
  Future<void> clear();
}

/// 기기에 남는 저장소. 앱이 쓰는 구현이다.
class HiveTicketStore extends TicketStore {
  /// [documentsDirectory] 는 테스트가 임시 폴더를 꽂기 위해 받는다. 앱에서는
  /// 제작·복원이 파일을 쓰는 곳과 같은 기기 문서 폴더다.
  HiveTicketStore(this.box, {Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  static const boxName = 'timo_memory_v1';

  final Box<String> box;
  final Future<Directory> Function() _documentsDirectory;

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

  /// 상자를 먼저 비워 목록에서 사라지게 하고, 그 다음 파일을 지운다.
  ///
  /// 파일은 소장품이 가리키는 것만 고르지 않고 제작·복원이 쓰는 폴더
  /// ([MemoryFiles.directories])를 통째로 지운다. 만들다 그만둔 사진·실패한
  /// 제작이 남긴 조각도 앞사람 것이라 함께 가야 한다. 파일 삭제가 실패해도
  /// 상자는 이미 비어 있어 목록에는 남지 않는다.
  @override
  Future<void> clear() async {
    await box.clear();
    notifyListeners();

    final root = await _documentsDirectory();
    for (final name in MemoryFiles.directories) {
      final directory = Directory('${root.path}/$name');
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    await for (final entry in root.list()) {
      if (entry is File &&
          entry.uri.pathSegments.last.startsWith(MemoryFiles.repairPrefix)) {
        await entry.delete();
      }
    }
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

  @override
  Future<void> clear() async {
    _tickets.clear();
    notifyListeners();
  }
}
