import 'dart:io';

import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/goods_record.dart';
import '../models/memory_ticket.dart';
import 'goods_api.dart';

/// 만든 소장품을 서버로 보낸다 — 이미지를 올려 key 를 받고, 그 key 로 생성
/// 요청을 보내는 두 걸음.
///
/// 두 걸음을 한 자리에 묶는 이유는 **순서로 짝을 맞추기** 때문이다. 업로드는
/// 올린 순서대로 key 를 돌려주므로, 어떤 파일을 어떤 순서로 올렸는지 아는 쪽만
/// 그 key 를 제자리에 써넣을 수 있다.
///
/// 이미지는 **여러 요청에 나눠** 올린다. 서버가 요청 하나를 30MB 까지만 받는데
/// (`spring.servlet.multipart.max-request-size`), 인물 둘이면 열 장 안팎이라
/// 사진 해상도에 따라 한 요청에 다 넣으면 넘친다. 요청마다 순서가 지켜지므로
/// 나눠 올린 key 를 이어 붙이면 한 번에 올린 것과 같다.
///
/// 화면은 이 결과를 기다렸다가 저장한다. 서버가 받은 뒤에 저장해야 "확정했는데
/// 서버에는 없는" 소장품이 남지 않는다.
class GoodsUploader {
  const GoodsUploader(
    this._api, {
    this.batchBytes = GoodsConstants.uploadBatchBytes,
  });

  final GoodsApi _api;

  /// 한 요청에 담는 파일 크기의 합 상한. 테스트가 작은 값으로 갈아 끼운다.
  final int batchBytes;

  Future<GoodsDetail> upload(MemoryTicket ticket) async {
    // 서버가 400 으로 거절할 것을 먼저 가린다. 여기서 막으면 수십 MB 를
    // 올린 뒤에 실패하는 일이 없다.
    if (ticket.personDepthLayers.length > GoodsConstants.maxPersonLayers) {
      throw const ApiException(GoodsText.invalidLayers);
    }

    final sizes = await _sizes(ticket.imagePaths);
    // 배경은 서버가 필수로 받는다. 파일이 사라졌으면(저장소 청소·기기 이전)
    // 올려 봐야 거절이라 여기서 끝낸다.
    if (!sizes.containsKey(ticket.backgroundPath)) {
      throw const ApiException(GoodsText.missingBackground);
    }

    final paths = sizes.keys.toList();
    final keys = <String>[];
    for (final batch in _batches(paths, sizes)) {
      keys.addAll(
        await _api.uploadImages(ticketId: ticket.ticketId, paths: batch),
      );
    }
    final table = {for (var i = 0; i < paths.length; i++) paths[i]: keys[i]};

    return _api.create(
      ticketId: ticket.ticketId,
      body: ticket.toGoodsJson(keys: table),
    );
  }

  /// 아직 기기에 남아 있는 파일만, 순서를 지켜 크기와 함께. 없는 파일을 올리려
  /// 하면 요청 자체가 만들어지지 않아 무엇이 없는지도 알 수 없다.
  Future<Map<String, int>> _sizes(List<String> paths) async {
    final sizes = <String, int>{};
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) sizes[path] = await file.length();
    }
    return sizes;
  }

  /// 순서를 바꾸지 않고 앞에서부터 상한까지 채워 묶는다. 한 장이 상한을 넘으면
  /// 혼자 간다 — 파일 하나를 나눌 수는 없고, 그건 서버의 장당 한도가 가린다.
  List<List<String>> _batches(List<String> paths, Map<String, int> sizes) {
    final batches = <List<String>>[];
    var current = <String>[];
    var total = 0;
    for (final path in paths) {
      final size = sizes[path]!;
      if (current.isNotEmpty && total + size > batchBytes) {
        batches.add(current);
        current = [];
        total = 0;
      }
      current.add(path);
      total += size;
    }
    if (current.isNotEmpty) batches.add(current);
    return batches;
  }
}
