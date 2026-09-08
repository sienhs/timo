# 백엔드·프론트 이미지 가이드

## 1. 어디에 업로드하나요?

리전은 모두 `ap-northeast-2`. 기존 이미지 전용 AWS 키로 두 버킷을 사용합니다.

| 구분 | S3 버킷 | 프론트 조회 |
|---|---|---|
| 공개: 공연장·포스터 | `ticketing-dev-images-023433588174` | CloudFront 고정 URL |
| 개인: 본인만 보는 이미지 | `ticketing-dev-private-images-023433588174` | 권한 확인 후 S3 임시 URL |

공개 이미지 기본 주소: `https://d3c4xr3c31ryfa.cloudfront.net`

## 2. DB에는 무엇을 저장하나요?

**전체 URL 대신 이미지 ID, 공개 여부, S3 파일 경로(key), 소유자를 저장합니다.**

| id | visibility | object_key | owner_id |
|---|---|---|---|
| 101 | PUBLIC | `venues/42/uuid.jpg` | null |
| 102 | PRIVATE | `users/7/uuid.jpg` | 7 |

버킷 이름은 서버 설정에서 공개 여부에 따라 선택합니다. 임시 URL은 만료되므로 DB에 저장하지 않습니다. 파일 경로의 사용자 번호만으로 권한을 판단하지 말고 DB 소유자/권한을 확인합니다.

## 3. JSON은 어떻게 내려주나요?

프론트에는 두 종류 모두 같은 `image` 구조로 내려줍니다. 아래 URL과 만료 시각은 설명용 예시입니다.

공개 이미지:

```json
{
  "image": {
    "id": 101,
    "url": "https://d3c4xr3c31ryfa.cloudfront.net/venues/42/uuid.jpg",
    "expiresAt": null
  }
}
```

개인 이미지:

```json
{
  "image": {
    "id": 102,
    "url": "https://ticketing-dev-private-images-023433588174.s3.ap-northeast-2.amazonaws.com/users/7/uuid.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&...",
    "expiresAt": "2026-09-08T08:05:00Z"
  }
}
```

개인 이미지 처리: **로그인 확인 → DB 이미지 조회 → 소유자/접근 권한 확인 → AWS SDK `S3Presigner`로 5분짜리 GET URL 생성**. 임의의 bucket/key를 클라이언트에게 받아 그대로 서명하지 않습니다. `expiresAt`은 실제 서명 만료 시각을 UTC로 반환합니다.

프론트는 `image.url`을 그대로 표시하고, 만료되면 이미지 ID로 백엔드에 새 URL을 요청합니다. 서명 URL의 쿼리를 수정하거나 AWS 키를 프론트에 넣지 않습니다. 이미지가 없으면 `image: null`을 반환합니다.

## 4. 구현 시 기억할 것

- 개인 URL은 만료 전까지 전달받은 누구나 사용 가능하므로 공유하지 않습니다. 개인 이미지와 해당 JSON에는 `Cache-Control: private, no-store`를 사용합니다. S3 업로드 메타데이터 또는 서명 생성 시 응답 헤더에도 반영합니다.
- 업로드 시 올바른 `Content-Type`을 지정하고 ACL은 설정하지 않습니다. 공개/개인 선택은 백엔드가 용도와 권한으로 결정합니다.
- 공개 이미지 교체 시 새 UUID 경로를 사용합니다. 같은 경로는 CloudFront 캐시 때문에 이전 이미지가 보일 수 있습니다.
- PUBLIC을 PRIVATE로 바꿀 때 DB 값만 바꾸면 안 됩니다. 개인 버킷으로 옮기고 공개 원본 삭제·CloudFront 캐시 무효화가 필요합니다. 이미 내려받은 사본은 회수할 수 없습니다.

**인프라는 적용 완료. DB 변경·권한 검사·URL 생성·JSON 응답은 백엔드에서 구현해야 합니다.**
