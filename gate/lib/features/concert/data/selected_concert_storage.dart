import '../../../core/storage/device_storage.dart';
import '../models/concert_summary.dart';

/// 이 단말이 검표하기로 고른 공연을 기기에 기억해 둔다.
///
/// 앱을 껐다 켤 때마다 목록에서 다시 고르게 하면, 공연 시작 직전에 앱이
/// 죽었을 때 줄 앞에서 공연을 찾아 헤매게 된다. 로그인이 그렇듯 고른 공연도
/// 되살린다.
///
/// 로그아웃해도 지우지 않는다. 교대하는 운영자가 서는 입구는 대개 같은
/// 입구다 — 다른 공연을 받아야 하면 스캔 화면의 '공연 변경' 으로 바꾼다.
/// 공연명·공연장·일시는 관람객에게도 공개되는 정보라 남아도 새어 나갈 것이
/// 없다.
class SelectedConcertStorage {
  const SelectedConcertStorage(this._storage);

  final DeviceStorage _storage;

  /// 저장 키. 인증 키와 접두사를 나눠 둔다.
  static const idKey = 'gate.concertId';
  static const titleKey = 'gate.concertTitle';
  static const venueKey = 'gate.concertVenue';
  static const startDateKey = 'gate.concertStartDate';
  static const endDateKey = 'gate.concertEndDate';

  /// 저장된 공연. 없거나 깨져 있으면 null 이라 공연 선택 화면부터 시작한다.
  ///
  /// 공연 ID 와 이름 둘 중 하나라도 없으면 없는 것으로 본다. 헤더에 이름을
  /// 못 띄우는 반쪽짜리 상태로 검표를 시작하는 것보다 다시 고르게 하는 쪽이 낫다.
  Future<ConcertSummary?> read() async {
    final id = int.tryParse(await _storage.read(idKey) ?? '');
    final title = await _storage.read(titleKey);
    if (id == null || title == null || title.isEmpty) return null;

    return ConcertSummary(
      id: id,
      title: title,
      venueName: await _storage.read(venueKey) ?? '',
      startDate: DateTime.tryParse(await _storage.read(startDateKey) ?? ''),
      endDate: DateTime.tryParse(await _storage.read(endDateKey) ?? ''),
    );
  }

  /// 고른 공연을 저장한다. 포스터는 담지 않는다 — 고르고 난 뒤로는 쓰지 않는다.
  Future<void> write(ConcertSummary concert) async {
    await _storage.write(idKey, concert.id.toString());
    await _storage.write(titleKey, concert.title);
    await _storage.write(venueKey, concert.venueName);
    await _writeOrDelete(startDateKey, concert.startDate);
    await _writeOrDelete(endDateKey, concert.endDate);
  }

  Future<void> clear() async {
    for (final key in [idKey, titleKey, venueKey, startDateKey, endDateKey]) {
      await _storage.delete(key);
    }
  }

  /// 날짜가 없으면 지운다. 그냥 두면 전에 고른 공연의 날짜가 남아 이번 공연의
  /// 것처럼 읽힌다.
  Future<void> _writeOrDelete(String key, DateTime? value) => value == null
      ? _storage.delete(key)
      : _storage.write(key, value.toIso8601String());
}
