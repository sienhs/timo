import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../data/creation_service.dart';
import '../data/ticket_store.dart';
import '../models/memory_concert.dart';
import '../models/memory_ticket.dart';
import '../models/photo_framing.dart';
import '../models/ticket_effect.dart';
import '../motion/ambient_motion.dart';

/// 마지막 단계에서 '다음으로' 를 누른 순간의 제작 입력 전부.
///
/// 제작 화면이 사라져도 job 이 살아 있어야 하므로 그 시점에 얼려 둔다.
class CreationDraft {
  const CreationDraft({
    required this.concert,
    required this.background,
    required this.people,
    required this.effect,
    required this.framing,
    this.aiExtended = false,
  });

  final MemoryConcert concert;

  /// 고른 사진, 또는 '쓰기' 를 누른 뒤의 AI 확장본.
  final String background;
  final List<Map<String, dynamic>> people;
  final TicketEffect effect;
  final PhotoFraming framing;

  /// [background] 가 생성형 아웃페인팅 결과일 때 참.
  final bool aiExtended;
}

sealed class CreationJobState {
  const CreationJobState();
}

class CreationIdle extends CreationJobState {
  const CreationIdle();
}

class CreationRunning extends CreationJobState {
  const CreationRunning(this.status);
  final String status;
}

class CreationDone extends CreationJobState {
  const CreationDone(this.ticket);
  final MemoryTicket ticket;
}

class CreationFailed extends CreationJobState {
  const CreationFailed(this.message, this.draft);
  final String message;
  final CreationDraft draft;
}

/// 앱 전체가 공유하는 '제작중' job.
///
/// 생성과 저장이 제작 화면이 아니라 여기서 돈다. 그래서 선물이 포장되는 동안
/// 사용자가 컬렉션으로 나가 있어도 되고, 끝나면 완료 배너가 다시 불러온다.
/// 화면보다 오래 살아야 하므로 App 이 하나 만들어 [CreationJobScope] 로
/// 내려준다.
class CreationJob extends ChangeNotifier {
  CreationJob({required this._store});

  final TicketStore _store;

  CreationJobState _state = const CreationIdle();
  CreationJobState get state => _state;

  bool get running => _state is CreationRunning;

  void _set(CreationJobState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> start(CreationDraft draft, {CreationService? service}) async {
    if (running) return;
    _set(const CreationRunning(CreatorText.processingTitle));
    final creation = service ?? CreationService();
    try {
      final ticket = await creation.generateTicket(
        concert: draft.concert,
        background: draft.background,
        people: draft.people,
        effect: draft.effect.label,
        framing: draft.framing,
        aiExtended: draft.aiExtended,
      );
      await _store.save(ticket);
      // 파티클을 한 번 치고 갈 만한 유일한 사건.
      AmbientMotion.instance.pulse();
      _set(CreationDone(ticket));
    } catch (_) {
      _set(CreationFailed(CreatorText.saveFailed, draft));
    }
  }

  /// 완성된 소장품을 열었거나(또는 실패를 확인했으면) 부른다.
  void acknowledge() => _set(const CreationIdle());
}
