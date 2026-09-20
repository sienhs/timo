import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/core/storage/device_storage.dart';
import 'package:timo_gate/features/concert/data/selected_concert_storage.dart';
import 'package:timo_gate/features/concert/models/concert_summary.dart';

void main() {
  const concert = ConcertSummary(
    id: 12,
    title: '저장 테스트 공연',
    venueName: '체조경기장',
    startDate: null,
    posterImageUrl: 'poster/12.png',
  );

  test('저장한 공연을 그대로 되살린다 (포스터는 담지 않는다)', () async {
    final storage = InMemoryDeviceStorage();
    final selected = SelectedConcertStorage(storage);

    await selected.write(
      ConcertSummary(
        id: 12,
        title: concert.title,
        venueName: concert.venueName,
        startDate: DateTime(2026, 11, 4, 18),
        endDate: DateTime(2026, 11, 6),
        posterImageUrl: concert.posterImageUrl,
      ),
    );
    final restored = await selected.read();

    expect(restored, isNotNull);
    expect(restored!.id, 12);
    expect(restored.title, concert.title);
    expect(restored.venueName, concert.venueName);
    expect(restored.startDate, DateTime(2026, 11, 4, 18));
    expect(restored.endDate, DateTime(2026, 11, 6));
    expect(restored.posterImageUrl, isNull);
  });

  test('아무것도 없으면 null', () async {
    final selected = SelectedConcertStorage(InMemoryDeviceStorage());
    expect(await selected.read(), isNull);
  });

  test('공연 ID 만 남고 이름이 없으면 없는 것으로 본다', () async {
    final selected = SelectedConcertStorage(
      InMemoryDeviceStorage({SelectedConcertStorage.idKey: '3'}),
    );
    expect(await selected.read(), isNull);
  });

  test('날짜 없는 공연을 덮어쓰면 이전 공연의 날짜가 남지 않는다', () async {
    final storage = InMemoryDeviceStorage();
    final selected = SelectedConcertStorage(storage);

    await selected.write(
      ConcertSummary(
        id: 1,
        title: '먼저',
        venueName: 'v',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 2),
      ),
    );
    await selected.write(concert);

    final restored = await selected.read();
    expect(restored!.id, 12);
    expect(restored.startDate, isNull);
    expect(restored.endDate, isNull);
    expect(
      storage.values.containsKey(SelectedConcertStorage.startDateKey),
      isFalse,
    );
  });

  test('clear 하면 전부 지운다', () async {
    final storage = InMemoryDeviceStorage();
    final selected = SelectedConcertStorage(storage);

    await selected.write(concert);
    await selected.clear();

    expect(storage.values, isEmpty);
    expect(await selected.read(), isNull);
  });
}
