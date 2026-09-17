# TIMO 메모리 티켓 · 앱 ↔ 백엔드 API 계약 (v1 초안, 2026-09-09)

앱은 공연 정보와 기본 소재(배경 3장·인물 3장·영상)를 받아, **기기 안에서** 누끼·합성·깊이 추정을 끝내고 **완성된 결과물만** 올립니다.
백엔드는 이펙트를 만들거나 이미지를 가공하지 않습니다. 이펙트는 파일이 아니라 이름표(`effectType`) 하나이며 앱이 셰이더로 실시간 렌더링합니다.

- Base URL `https://{host}/api/v1`, JSON UTF-8
- 인증 `Authorization: Bearer {accessToken}` (소유자는 토큰으로 판별)
- 날짜 `YYYY-MM-DD`, 시각 `HH:mm`, 타임스탬프 ISO 8601 (`+09:00`)
- 미디어 URL은 절대 HTTPS, presigned면 유효 1시간 이상
- 목록은 `?cursor=&limit=`(기본 50), 응답 `nextCursor`(없으면 null)
- 업로드 멱등 키 `clientTicketId` (재전송 시 기존 티켓 200)

## 흐름

1. `GET /me/concerts` 내가 본 공연 목록 (좌석·소유자 포함)
2. `GET /concerts/{id}/kit` 배경 3·인물 3·영상
3. 소재 선택/갤러리 추가 — 서버 호출 없음
4. 기기에서 완성 — 누끼·합성·깊이·이펙트 선택. 서버 호출 없음
5. `POST /tickets` 이미지 3장 + 메타 JSON 업로드
6. `POST /tickets/{id}/mint`, `GET /me/tickets` 민팅·복원

## 1. GET /me/concerts

```json
{
  "concerts": [{
    "concertId": "concert-1024",
    "title": "빛으로 남은 밤",
    "artist": "TIMO STAGE",
    "date": "2026-09-26",
    "time": "19:00",
    "venue": "서울 메모리 홀",
    "posterUrl": "https://cdn.timo.app/concerts/1024/poster.jpg",
    "ticket": {
      "ticketNumber": "T-20260926-000124",
      "seat": { "section": "스탠딩 A", "number": "024", "gate": "GATE 2", "label": "스탠딩 A · 024" },
      "owner": { "userId": "u_8f21", "displayName": "우진" }
    },
    "hasMemoryTicket": false
  }],
  "nextCursor": null
}
```

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| concertId | string | 필수 | 키트 조회·업로드에 그대로 사용 |
| title / artist | string | 필수 | 티켓 뒷면에 인쇄 |
| date / time | string | 필수 / 선택 | |
| venue | string | 선택 | |
| posterUrl | url | 선택 | 없으면 배경 1번으로 대체 |
| ticket.seat.label | string | 필수 | 좌석 한 줄 표시 |
| ticket.owner.displayName | string | 필수 | 소유자 표시 이름 |
| ticket.ticketNumber | string | 선택 | 예매 번호 |
| hasMemoryTicket | boolean | 선택 | 이미 만든 공연 배지 |

## 2. GET /concerts/{concertId}/kit

티켓 미보유 공연이면 403.

```json
{
  "concertId": "concert-1024", "title": "빛으로 남은 밤", "artist": "TIMO STAGE",
  "date": "2026-09-26", "time": "19:00", "venue": "서울 메모리 홀",
  "ticket": { "ticketNumber": "...", "seat": { "...": "..." }, "owner": { "...": "..." } },
  "backgrounds": [
    { "assetId": "bg_1024_01", "url": "https://cdn.timo.app/kits/1024/bg_01.jpg",
      "thumbnailUrl": "https://cdn.timo.app/kits/1024/bg_01_t.jpg",
      "width": 1920, "height": 1080, "caption": "오프닝 무대" }
  ],
  "people": [
    { "assetId": "ps_1024_01", "url": "https://cdn.timo.app/kits/1024/person_01.png",
      "thumbnailUrl": "https://cdn.timo.app/kits/1024/person_01_t.jpg",
      "width": 1200, "height": 1800, "label": "멤버 A", "cutout": true }
  ],
  "video": {
    "videoId": "concert-1024-main",
    "url": "https://cdn.timo.app/videos/1024/immersive.mp4",
    "posterUrl": "https://cdn.timo.app/videos/1024/immersive_first.jpg",
    "durationMs": 6000, "width": 1080, "height": 1920, "mimeType": "video/mp4"
  }
}
```

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| backgrounds[] | Asset ×3 | 필수 | 앱이 9:14로 자르거나 여백을 채움 (미러·블러) |
| people[] | Asset ×3 | 필수 | `cutout: true`면 투명 PNG, 누끼 단계 생략 |
| Asset.url / width / height | url, int | 필수 | 픽셀 크기가 있으면 편집기 배치가 즉시 맞음 |
| Asset.thumbnailUrl | url | 선택 | 격자용, 긴 변 400px |
| Asset.label / caption | string | 선택 | |
| video.url | url | 필수 | H.264 MP4, faststart, HTTP Range 지원 |
| video.videoId | string | 필수 | 업로드 시 그대로 회신 |
| video.durationMs | int | 선택 | 손 떼도 끝까지 재생하는 기준 |

## 3. POST /tickets (multipart/form-data)

성공 201, 같은 `clientTicketId` 재전송은 200.

| 파트 | 형식 | 필수 | 설명 |
|---|---|---|---|
| ticket | application/json | 필수 | 아래 메타 |
| background | image/png·jpeg | 필수 | 9:14 보정 배경, 1080×1680, ≤8 MB |
| person | image/png RGBA | 필수 | 인물 합성 레이어, 투명 배경, 900×1200, ≤8 MB |
| depth | image/png 8-bit gray | 필수 | 배경 깊이 맵, 518×806 내외 (0 멀리, 255 가까이) |
| preview | image/jpeg | 선택 | 카드 정면 캡처 720×1120, ≤2 MB |

```json
{
  "clientTicketId": "1757400123456789",
  "concertId": "concert-1024",
  "videoId": "concert-1024-main",
  "effectType": "laser",
  "sources": { "backgroundAssetId": "bg_1024_01", "peopleAssetIds": ["ps_1024_02", null] },
  "transition": { "brightness": -0.04, "saturation": 1.08, "contrast": 1.05, "tint": -14536452,
                  "durationMs": 610, "blur": 9.6, "distance": 0.4, "firstFrameAnalyzed": true },
  "processing": { "backgroundExtension": "ai", "extensionModel": "gpt-image-2",
                  "notes": ["인물 1: ML Kit 누끼 · 전신 · 얼굴 분석 완료"] },
  "createdAt": "2026-09-09T14:22:03+09:00"
}
```

- `effectType`: `confetti | laser | stageLights | curtain | none`
- `sources.*AssetId`가 null이면 사용자 갤러리 사진
- `transition`은 서버가 해석하지 않고 그대로 보관

응답 201:

```json
{
  "ticketId": "mt_01J7…",
  "clientTicketId": "1757400123456789",
  "concertId": "concert-1024",
  "effectType": "laser",
  "videoId": "concert-1024-main",
  "media": {
    "backgroundUrl": "https://cdn.timo.app/tickets/mt_01J7/background.png",
    "personUrl": "https://cdn.timo.app/tickets/mt_01J7/person.png",
    "depthUrl": "https://cdn.timo.app/tickets/mt_01J7/depth.png",
    "previewUrl": "https://cdn.timo.app/tickets/mt_01J7/preview.jpg"
  },
  "mint": { "status": "NOT_MINTED" },
  "createdAt": "2026-09-09T14:22:03+09:00"
}
```

서버가 하는 것: MIME·용량 검사, 저장, URL 발급, 소유 확인. 하지 않는 것: 리사이즈, 누끼, 배경 확장, 깊이 추정, 이펙트 렌더.

## 4. GET /me/tickets, GET /tickets/{ticketId}

업로드 응답 + `concert` 요약(`concertId, title, artist, date, time, venue, ticket{seat, owner, ticketNumber}, video{videoId, url, durationMs}`) + `transition`. 목록은 최신 순 커서 페이지네이션.
`DELETE /tickets/{ticketId}` → 204, 민팅 COMPLETED면 409.

## 5. 민팅

상태: `NOT_MINTED | PENDING | COMPLETED | FAILED`

- `POST /tickets/{ticketId}/mint` → 202 `{ "status": "PENDING", "requestedAt": "..." }`
- `GET /tickets/{ticketId}/mint` → `{ "status", "tokenId", "transactionHash", "metadataUrl", "failureReason" }`

## 미디어 규격

| 구분 | 형식 | 권장 크기 | 비고 |
|---|---|---|---|
| 기본 배경 (서버→앱) | JPEG/PNG | 긴 변 ≥1920 | 세로(9:14 근접) 사진이면 잘림이 적음 |
| 기본 인물 (서버→앱) | PNG RGBA | 인물 높이 ≥1200 | 전신 권장 |
| 이머시브 영상 (서버→앱) | MP4 H.264+AAC | 1080×1920, 24~30fps, 6~15초 | faststart, Range |
| 완성 배경 (앱→서버) | PNG/JPEG | 1080×1680 | |
| 인물 합성 (앱→서버) | PNG RGBA | 900×1200 | |
| 깊이 맵 (앱→서버) | PNG 8-bit gray | 518×806 | |
| 미리보기 (앱→서버) | JPEG | 720×1120 | 선택 |

## 오류

```json
{ "error": { "code": "TICKET_NOT_OWNED", "message": "이 공연의 티켓을 보유하고 있지 않아요." } }
```

| HTTP | code | 상황 |
|---|---|---|
| 401 | UNAUTHORIZED | 토큰 없음·만료 |
| 403 | TICKET_NOT_OWNED | 내 공연이 아닌 요청 |
| 404 | CONCERT_NOT_FOUND / TICKET_NOT_FOUND | |
| 409 | TICKET_MINTED | 민팅 완료 티켓 삭제 |
| 413 | FILE_TOO_LARGE | |
| 422 | INVALID_MEDIA / INVALID_FIELD | MIME 불일치, 파트 누락, effectType 오류 |

`message`는 앱이 그대로 토스트로 보여줄 한국어 문장.
