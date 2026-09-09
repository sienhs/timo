# blockchain/

TIMO(티켓팅 플랫폼) 온체인 파트

## 스택

- **Solidity 0.8.24 + Hardhat 2.x (TypeScript) + ethers.js v6**
- OpenZeppelin Contracts (ERC721, AccessControl 등)
- 개발망: Hardhat 내장 네트워크 → 필요 시 `localhost`(`npm run node`) → 데모 시 Polygon Amoy 테스트넷(`--network amoy`)

Hardhat 3(최신 메이저)이 아니라 2.x를 고정한 이유: OpenZeppelin/Solidity 튜토리얼 생태계 대부분이 아직 2.x 기준이고, 3.x는 viem 기본·ESM 전용 등으로 학습곡선이 커서 지금 단계엔 안 맞음.

## 왜 커스터디얼인가 / 가스비는 어떻게

- 회원가입 완료 시 서버가 실제 EOA(주소+개인키)를 생성하고, 개인키는 서버가 암호화 보관·서명 대행. 유저는 블록체인 존재 자체를 모름.
- **가스는 체인 네이티브 코인으로만 낼 수 있어 우리가 만든 자체 코인으로는 못 냅니다.** 대신 모든 온체인 트랜잭션은 유저 지갑이 아니라 서비스가 운영하는 오퍼레이터/릴레이어 지갑이 대신 쏘고, 유저 지갑 주소는 소유자 필드로만 기록됩니다. 그래서 네이티브 가스 코인이 필요한 지갑은 유저 수가 아니라 오퍼레이터 지갑 1~2개뿐이고, 테스트넷에서는 그마저도 페이셋으로 무료로 받으면 됩니다.
- 입장 검증용 지갑 서명(`personal_sign`)은 오프체인 메시지 서명이라 가스가 아예 안 듭니다 — 유저 개인키가 실제로 쓰이는 유일한 순간.
- 앱에 보이는 "코인"(예치 잔액)은 블록체인 가스와 완전히 별개 레이어입니다. `TicketVault` 컨트랙트 안의 주소별 잔액 매핑일 뿐, 전송 가능한 토큰이 아니라 구매력 회계용 숫자입니다.

## 현재 구현된 것

### `src/wallet/custodialWallet.ts` — 커스터디얼 지갑 생성/복호화 (envelope encryption)

- `createCustodialWallet(userId)` — 새 EOA 생성 → **지갑마다 랜덤 DEK(32바이트) 생성** → 그 DEK를 패스워드 삼아 Ethereum V3 키스토어(scrypt)로 개인키 암호화 → DEK 자체는 마스터키로 AES-256-GCM 래핑(`wrappedDek`). 반환값은 `{ userId, address, encryptedKeystoreJson, wrappedDek }` 두 조각 — 평문 개인키도, 평문 DEK도 호출자에게 노출 안 됨.
- `loadCustodialWallet({ encryptedKeystoreJson, wrappedDek })` — 마스터키로 DEK를 먼저 풀고, 그 DEK로 키스토어를 복호화해 서명 가능한 `Wallet`로 복원.
- **왜 DEK를 하나 더 두나**: 마스터키 하나로 전체를 직접 암호화하던 이전 방식은 그 하나가 유출되면 전체 지갑이 한 번에 뚫림. 지금은 지갑마다 다른 키로 암호화돼 있고, 마스터키는 "그 DEK들을 푸는 열쇠" 역할만 함 — 실제 KMS(AWS KMS 등) envelope encryption이랑 같은 구조. `getMasterKey()`만 나중에 진짜 KMS 호출로 바꾸면 되고 호출부는 안 건드려도 됨(코드 주석 참고).
- 마스터키(`WALLET_MASTER_KEY`)는 64자리 hex 문자열(32바이트) 형식을 강제 검증함 — 예전엔 "값이 있기만 하면" 통과했는데, 지금은 형식이 틀리면 바로 명확한 에러를 던짐.
- AES-256-GCM은 **인증된 암호화**라, 마스터키가 틀리거나 `wrappedDek`이 변조되면 복호화가 조용히 이상한 값을 뱉는 게 아니라 즉시 실패함 (테스트로 확인).
- 지금도 마스터키 자체는 여전히 `.env` 환경변수 하나 — 완전한 프로덕션 대응은 아니고, "지갑 하나 뚫려도 전체가 안 뚫리게" + "나중에 KMS로 바꾸기 쉽게" 두 가지만 먼저 해결한 상태.

```bash
cd blockchain
npm install
cp .env.example .env
# WALLET_MASTER_KEY 채우기:
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

npm test                # 지갑 + TicketNFT + TicketVault + Marketplace + ShowRegistry + 입장검증 전체 단위 테스트 (93개)
npm run wallet:create   # 실제 지갑 하나 생성해서 주소·암호화된 키스토어+wrappedDek 출력
```

### `contracts/TicketNFT.sol` — 좌석 단위 전송제한 티켓 NFT

- 좌석(`showId`+`seatId`) 하나당 tokenId 하나, 평생 재사용 — 취소돼도 새로 mint하지 않고 `revoke`→`reissue`로 같은 토큰을 다음 소유자에게 넘김. 그래서 좌석 하나의 전체 소유 이력이 토큰 하나에 계속 쌓임.
- 상태: `NONE → OWNED ⇄ LISTED → (settleTransfer) OWNED(새 소유자)` / `OWNED → REVOKED → (reissue) OWNED` / `OWNED → USED → SOUVENIR`
- **이전 잠금의 실제 구현**: `_update` 훅에서 `auth != address(0)`이면 무조건 revert. `transferFrom`/`safeTransferFrom` 같은 공개 진입점은 항상 `msg.sender`를 auth로 넘기고, 우리 컨트랙트 내부 함수들은 `_update`를 직접 `auth=address(0)`으로 호출하므로, 이 한 줄이 "화이트리스트된 4개 경로(mint/양도체결/회수/재발급) 외엔 전부 막힌다"를 보장함. 정책 추가는 `_isTransferAllowed`만 고치면 됨 — 컨트랙트 재작성 불필요.
- `approve`/`setApprovalForAll`은 아예 revert — 지갑/익스플로러에 "이거 승인됨"으로 오해할 여지 자체를 차단.
- Role: `ORGANIZER_ROLE`(mint) / `MARKETPLACE_ROLE`(settleTransfer, 아직 없는 Marketplace 컨트랙트용) / `OPERATOR_ROLE`(revoke/reissue/소장품 전환) / `GATE_ROLE`(입장 처리)
- **`ShowRegistry` 연결됨**: `mintTicket(to, showId, seatId)` — `facePrice` 파라미터가 아예 없어졌습니다. 대신 `showRegistry.facePriceOf(showId)`로 정가를 직접 조회하고(존재하지 않는 showId면 여기서 `ShowDoesNotExist`로 revert), `showRegistry.isSaleOpen(showId)`가 false면 `SaleNotOpen`으로 막습니다. 호출자가 잘못된/거짓 가격을 넘길 방법 자체가 사라진 것 — "신뢰"가 아니라 "조회"로 바뀜.
- `showRegistry` 주소는 `custodyVault`처럼 admin이 나중에 바꿀 수 있게(`setShowRegistry`) `immutable`이 아님 — `Marketplace`와 다르게, `TicketNFT`를 다시 배포하면 이미 발행된 모든 티켓을 잃기 때문에 재배포보다 주소 교체가 안전한 선택.
- `holdsShow[addr][showId]` — "1인 1매" 제약. mint/settleTransfer/reissue에서 이미 그 공연 티켓을 보유 중이면 revert, revoke되면 다시 예매 가능하도록 해제. 1차 발행과 2차 구매 양쪽 다 적용됨(마켓만 막으면 1차로 우회 가능하므로 여기 있어야 함).
- 테스트 27개: mint 검증, 1인 1매, 전송 잠금, 상세 승인 차단, 리스팅/정산, 취소/승계, 입장/소장품 전환, 역할별 권한 거부까지 커버

### `contracts/TicketVault.sol` — 예치 잔액 내부 원장

ERC-20이 아닙니다 — 아무도 이 잔액을 직접 전송할 수 없고, 컨트랙트 밖으로 나가지도 않습니다. PG가 오프체인에서 실제 결제를 확인하면 백엔드(`OPERATOR_ROLE`)가 그만큼을 `deposit`으로 반영하는 순수 회계 장부입니다.

- `balanceOf[addr]` — 사용 가능 잔액, `lockedOf[addr]` — 승계 대기로 잠긴 잔액 (둘은 분리되어 있어 잠긴 돈은 다른 데 못 씀)
- `deposit(user, amount, refId)` — PG 충전 반영
- `chargeForBooking(buyer, organizer, amount, orderId)` — **1차 예매 차감이자 동시에 주최사 정산.** buyer 잔액을 깎고 그대로 organizer 잔액에 적립. 스펙의 "1차 판매 대금은 주최사 계정 잔액으로 누적"이 이 한 함수.
- `settleTransfer(seller, buyer, price, tradeId)` — `MARKETPLACE_ROLE` 전용. **1차 차감과 2차 지급이 같은 `balanceOf` 매핑을 쓰기 때문에**, 2차 거래로 잔액을 다 쓴 유저는 그 직후 1차 예매 결제가 자동으로 실패합니다(테스트로 확인함) — 계층 간 이중사용이 구조적으로 불가능.
- `lockForWaitlist` / `unlockWaitlist` / `claimWaitlistSeat` — 승계 대기열. 등록 시 최고 등급 정가를 잠그고, 실제 회수된 좌석 정가(더 낮을 수 있음)만큼만 주최사에 지급한 뒤 차액은 사용 가능 잔액으로 자동 환원.
- `refund(user, amount, refId)` — 취소 환불/발행실패 보상용. 수수료 없이 그대로 적립.
- 모든 함수가 호출자가 넘긴 `bytes32 refId`(주문ID/거래ID/대기ID)를 소비형으로 처리 — 같은 ID로 재호출하면 `DuplicateOperation`. 백엔드가 재시도해도 이중 처리 안 됨.
- 테스트 21개: 충전/차감/정산/잠금-해제-클레임 정상 경로, 권한 거부, replay 방지, 그리고 "2차 거래로 잔액 소진 후 1차 결제 실패" 교차 레이어 테스트까지.

**미확정으로 남겨둔 것**: 양도 등록 취소 시 페널티(D-7 100%/하루 80%/당일 10% 중 미정)는 아직 구현 안 함 — 지금 `TicketNFT.delist()`는 금전적 결과 없이 상태만 되돌립니다. 결정되면 Vault에 페널티 차감 로직을 추가해야 합니다.

### `contracts/Marketplace.sol` — 2차 거래 정산 오케스트레이터

이 컨트랙트 자체는 새로운 비즈니스 규칙이 없습니다. `TicketNFT.settleTransfer`와 `TicketVault.settleTransfer`를 **한 함수(`buy`) 안에서 순서대로 호출**할 뿐이고, 검증(리스팅 존재/가격/1인1매/잔액)은 전부 그 두 컨트랙트 안에 이미 있습니다. 이렇게 묶는 것 자체가 스펙의 "대금 수령·소유 이전·판매자 정산이 단일 트랜잭션" 요구사항 — 어느 한쪽이 실패하면 EVM 트랜잭션 전체가 되돌아가므로 별도 에스크로/롤백 코드가 필요 없습니다.

- `buy(tokenId, buyer, tradeId)` — `OPERATOR_ROLE`(백엔드) 전용. `ticketNFT.ownerOf`로 seller 조회 → `ticketNFT.settleTransfer`(소유권 이전, price 반환받음) → `ticketVault.settleTransfer`(그 price로 정산). 買者는 직접 이 함수를 호출하지 않음 — 완전 커스터디얼 구조 그대로.
- **배포 후 반드시 해줘야 하는 설정**: Marketplace 컨트랙트 주소에 `TicketNFT.MARKETPLACE_ROLE`과 `TicketVault.MARKETPLACE_ROLE`을 각각 grant해야 `buy`가 실제로 동작합니다. 컨트랙트가 스스로 권한을 부여받을 수 없어서, 이건 배포 스크립트(아직 없음)나 admin이 수동으로 해야 함.
- `ticketNFT`/`ticketVault` 주소는 `immutable` — 배포 후 못 바꿈. 다른 컨트랙트 쌍을 가리키게 하려면 새 Marketplace를 배포해야 하는 게 맞다고 판단(운영 중 주소를 몰래 바꿀 수 있으면 그 자체가 러그풀 벡터).
- 테스트 5개: 정상 구매, 권한 거부, 그리고 **원자성 3종** — 잔액 부족 시 NFT도 그대로 LISTED로 남는지, 1인1매 위반 시 아무것도 안 움직이는지, `tradeId` 재사용 시 (NFT 단계는 이미 성공했음에도) 트랜잭션 전체가 롤백돼서 NFT 소유권도 원상복구되는지까지 직접 검증함.

### `contracts/ShowRegistry.sol` — 공연 정가·일정 카탈로그

**스펙 모순 하나를 확인하고 결정한 뒤 만듦**: "모든 좌석은 동일한 금액" + "좌석별 등급은 성립하지 않는다"(공연·좌석 도메인) vs 승계 대기 설명의 "가장 높은 등급의 정가"(예매 도메인)가 서로 안 맞아서, **공연당 단일 정가로 확정**(등급 없음). 승계 대기 쪽 "등급" 표현은 이전 초안이 남은 문구로 간주.

이 컨트랙트는 딱 카탈로그 역할만 합니다 — 개별 좌석이나 발행 수량은 안 세고(그건 `TicketNFT`의 `seatTokenId`), 돈도 안 만짐(`TicketVault`). `TicketNFT.mintTicket`이 이제 이 값을 조회/대조합니다(위 TicketNFT 섹션 참고).

- `registerShow(facePrice, totalSeats, saleOpenTime, showTime, metadataURI)` — `ORGANIZER_ROLE`. 포스터/상세설명/장소 같은 무거운·가변 데이터는 `metadataURI`로 오프체인 참조만 함.
- `updateShow(...)` — **REGISTERED 상태 + `saleOpenTime` 이전까지만** 수정 가능. "정가표를 공연 등록 시점에 먼저 올린다" + "발행 이후 정가는 변경되지 않는다"를 만족시키려면, 이미 그 가격을 보고 있을 구매자가 생기기 전(=예매 오픈 전)까지만 편집 가능해야 한다고 판단.
- `cancelShow(showId)` — 쇼 시작 **D-7까지만** 가능(`CANCELLATION_DEADLINE = 7 days`). 실제로 이미 발행된 티켓들을 회수·환불하는 건 이 컨트랙트가 하지 않음 — 어떤 tokenId들이 그 공연 소속인지 이 컨트랙트는 모르고, 알 수 없는 개수만큼 온체인에서 루프 도는 건 가스 한도에 걸리기 쉬운 안티패턴이라 백엔드가 이벤트로 tokenId를 모아서 `TicketNFT.revoke`+`TicketVault.refund`를 각각 호출하는 방식으로 오케스트레이션해야 함.
- `endShow(showId)` — `OPERATOR_ROLE` 전용(주최사 본인 X). 쇼 실제 종료 시각이 지나야 가능. "정말 끝났는지"를 주최사 말이 아니라 플랫폼이 판단하도록.
- `isSaleOpen(showId)` — `organizer != 0 && status == REGISTERED && now >= saleOpenTime` 한 줄 뷰 함수. "예매 오픈 시각 이전에는 좌석 선택이 성립되지 않는다"를 다른 컨트랙트/백엔드가 값싸게 확인할 수 있게. `TicketNFT.mintTicket`이 이 값을 직접 씀. (`organizer != 0` 체크는 버그 수정: 등록된 적 없는 showId는 구조체가 전부 0으로 초기화돼 있어서 `status`가 우연히 `REGISTERED`(enum 0번)로 읽히고 `saleOpenTime`도 0이라, 이 체크가 없으면 "등록도 안 된 공연인데 예매 오픈 중"으로 잘못 나옴 — `TicketNFT` 연결 작업 중 테스트 짜다가 발견해서 같이 고침)
- `facePriceOf(showId)` — `mintTicket`이 쓰는 가벼운 조회용 getter. 존재하지 않는 showId면 `ShowDoesNotExist`로 revert.
- 테스트 25개: 등록 검증, 수정 가능 시점, D-7 경계(정확히 그 시점 포함), 종료 시점, 권한 거부, `isSaleOpen`/`facePriceOf` 상태 전이 및 미등록 showId 처리까지.

**전체 스위트 93개 전부 통과** (지갑 9 + TicketNFT 27 + TicketVault 21 + Marketplace 5 + ShowRegistry 25 + 입장검증 6).

### 배포/시딩 스크립트

**주최사 자체 등록 기능은 없습니다** — 실제 공연 정보를 외부에서 받아올 방법이 없어서, 팀이 더미데이터를 직접 넣기로 했습니다. 이건 컨트랙트를 바꿀 이유가 안 됩니다: `ORGANIZER_ROLE`은 애초에 "진짜 사업자 계정"이 아니라 그냥 주소 기반 권한이라, 관리자가 자기 자신에게 grant해서 스크립트로 대신 등록하면 그만입니다. 그래서 대신 이 두 스크립트를 만들었습니다.

```bash
npm run deploy   # scripts/deploy/deploy.ts — 4개 컨트랙트 배포 + Marketplace 쪽 role 상호 grant
npm run seed     # scripts/seed/seedDummyShows.ts — deploy 실행 + 더미 주최사·공연 등록
```

- `deploy.ts`는 `deployContracts(admin, custodyVaultAddress)`를 export해서 `seed.ts`가 그대로 재사용합니다. `ADMIN_ADDRESS`/`CUSTODY_VAULT_ADDRESS` 환경변수로 배포 계정과 다른 주소를 admin으로 지정할 수 있는데, 그 경우 role grant는 스크립트가 대신 못 해주니 admin이 직접 해야 한다고 로그로 알려줍니다.
- `deployContracts`는 배포가 끝날 때마다 4개 컨트랙트 주소를 `tmp/deployment.json`에 기록합니다 (`deploy`/`seed`/`mint:demo`/`flow:demo`/`qr:live` 전부 내부적으로 이 함수를 쓰므로 무엇을 실행하든 자동으로 남음). `scripts/demo/listTickets.ts`가 "직전에 뭘 배포했는지"를 알아내는 유일한 방법이 이 파일이라 만들었습니다.
- `seed.ts`는 더미 주최사 3곳(각자 실제 커스터디얼 지갑 — `src/wallet/custodialWallet.ts` 재사용)을 만들어 공연 6개를 등록합니다. **더미 주최사 지갑을 하나로 통일하지 않고 여러 개로 나눈 이유**: `TicketVault.chargeForBooking`이 주최사별로 판매 대금을 따로 적립하는데, 지갑을 하나로 합치면 "주최사별 정산" 자체가 데모에서 의미가 없어짐.
- 모든 더미 공연은 `saleOpenTime`이 이미 지난 채로 등록돼서, 시딩 직후 바로 예매(mint) 테스트가 가능합니다.
- 더미 주최사 지갑에 소량의 네이티브 가스를 직접 보내서 자기 트랜잭션을 자기가 보내게 했는데, 이건 이 스크립트에 릴레이어가 없어서 그런 것뿐이고 실제 프로덕션에서 주최사가 가스를 쥐고 있어야 한다는 뜻은 아닙니다 (위 "왜 커스터디얼인가" 참고 — 실제로는 백엔드가 대신 쏨).

**`seed-data/dummy-shows.json`** — 실제 더미 공연/주최사 데이터는 스크립트 안이 아니라 이 JSON 파일에 있습니다. 온체인에 올라가는 값(정가, 좌석수, 판매기간)만 여기 있고, 프론트에 보여줄 진짜 콘텐츠(포스터, 상세설명, 좌석 배치도)는 `metadataURI`에 지금은 플레이스홀더 문자열만 들어있는 상태입니다.

> **주최사 등록 화면이 따로 없는 이유**: 실제 공연 정보를 외부에서 받아올 방법이 없어서, "주최사 등록"이라는 기능 자체를 안 만들고 팀이 직접 이 시딩 스크립트로 대체하기로 했습니다. 온체인 데이터(가격/기간/주최사 지갑)와 오프체인 데이터(포스터/설명 등, 나중에 백엔드 MySQL에 들어갈 것)는 서로 다른 저장소라 자동으로 동기화되지 않는데, 이 JSON 파일을 **두 시딩 스크립트가 공유하는 단일 소스**로 두면, 백엔드가 생겼을 때 그 시딩 스크립트도 같은 파일을 읽게 만들어서 "온체인 6개 공연, DB엔 3개만" 같은 어긋남을 방지할 수 있습니다. 배열 순서가 곧 온체인 `showId`(1부터, 등록 순서대로)이므로, 이 파일의 순서를 바꾸면 showId도 같이 바뀝니다.

### `src/entry/entryVerification.ts` — 입장 검증 (동적 코드 + 지갑 서명)

스펙: "입장은 동적 코드와 소유 지갑의 서명, 두 가지를 함께 검증해 처리한다." 서명만으로는 부족한 게, 서명 자체는 유효기간이 없어서 캡처된 QR을 나중에 다시 써도 서명 검증은 통과해버림 — 그래서 **짧은 시간에 만료되고 한 번 쓰면 재사용 못 하는 동적 코드**를 서명과 묶어서 같이 검증합니다.

- `generateDynamicCode(tokenId, ttlSeconds)` — 랜덤 코드 + 발급/만료 시각 발급 (기본 15초, 정상 입장 검증이 3초 이내에 끝나야 한다는 스펙 조건 대비 여유 있게 잡음). 지금은 클라이언트 시뮬레이션이고, 실제로는 백엔드가 발급하는 게 더 안전(클라이언트가 스스로 만료시간을 조작 못 하게).
- `signEntryQr(signer, dynamicCode)` — `tokenId:code:expiresAt`를 하나로 묶어서 서명. 코드나 만료시각이 조금이라도 바뀌면 서명 검증이 깨지도록 셋을 함께 바인딩.
- `verifyEntryQr(payload, currentOwner, consumedCodes)` — 게이트 스캐너가 스캔마다 돌리는 함수. **세 가지를 전부 통과해야 `allowed: true`**:
  1. `now <= expiresAt` (코드 만료 안 됐는지)
  2. `!consumedCodes.has(code)` (같은 QR 재사용/캡처 아닌지 — 통과 시 이 함수가 직접 `consumedCodes`에 추가)
  3. 서명에서 복구한 주소가 **호출 시점에 조회한** `currentOwner`와 일치하는지 (양도로 소유자가 바뀐 뒤 이전 소유자의 예전 QR을 쓰면 여기서 걸림)
- `currentOwner`/`consumedCodes`는 이 모듈이 들고 있지 않고 **호출자가 넘겨줌** — 실제로는 `TicketNFT.ownerOf(tokenId)`를 스캔 시점마다 새로 조회하고, `consumedCodes`는 모든 게이트가 공유하는 DB 테이블이어야 해서 순수 로직만 여기 두고 저장소는 분리했습니다.
- 테스트 6개: 정상 통과, 만료 거부, 재사용 거부, 소유자 불일치(양도 후 구 소유자 서명) 거부, payload 변조 거부, 실패 시 `consumedCodes`에 안 쌓이는지까지.

### `scripts/demo/fullUserFlow.ts` — 회원가입→지갑생성→충전→예매→입장검증→게이트 풀 플로우

백엔드(Spring Boot)가 아직 없어서, "로그인 이후 벌어지는 일"을 blockchain/ 안에서 실제 컨트랙트로 전부 이어붙여 검증하는 스크립트입니다. 각 컴포넌트를 따로 테스트한 것과 다르게, **지갑이 실제로 나머지 시스템에서 쓸모 있게 동작하는지**를 하나의 시나리오로 증명합니다.

```bash
npm run flow:demo
```

순서: 컨트랙트 배포/role 세팅 → 주최사가 공연 등록 → `createCustodialWallet`로 회원가입 시 지갑 생성 → `TicketVault.deposit`로 PG 충전 반영 → `TicketNFT.mintTicket`+`TicketVault.chargeForBooking`으로 예매 → `generateDynamicCode`+`signEntryQr`로 입장용 QR 생성 → **게이트 스캔 1회차**: `verifyEntryQr`로 검증 통과했을 때만 `TicketNFT.markUsed` 호출 → **게이트 스캔 2회차**: 같은 QR을 다시 스캔하면 `이미 사용된 코드`로 거부되는 것까지 확인.

**여기서 확인되는 것**: 지갑의 개인키가 실제로 필요한 유일한 순간(QR 서명)부터, 그 QR이 검증을 통과해야만 온체인 상태가 바뀐다는 것, 그리고 같은 QR을 캡처해서 재사용해도 막힌다는 것까지 끊김 없이 이어짐. 이 스크립트가 백엔드 개발 시 "어떤 순서로 어떤 함수를 호출해야 하는지"의 참고 자료가 됩니다.

**실제 QR 이미지도 생성합니다** (`qrcode` 패키지) — 5단계에서 서명된 payload(`JSON.stringify(qrPayload)`)를 그대로 QR로 인코딩해서 (1) 터미널에 ASCII로 바로 찍고 (2) `blockchain/tmp/entry-qr-demo.png`로 저장합니다. 터미널 QR은 폰 카메라로 바로 스캔해볼 수 있고, PNG는 `.gitignore`된 `tmp/`에 저장되니 커밋 걱정 없이 매번 새로 생성됩니다. 실제 스캐너 앱을 만들면 이 payload를 `JSON.parse`해서 `verifyEntryQr`에 그대로 넘기면 됩니다.

### `scripts/demo/liveEntryQr.ts` — 유저 화면(QR 회전) + 게이트 스캔을 한 터미널에서

```bash
npm run qr:live   # Enter = 지금 화면의 QR을 스캔, 종료: Ctrl+C
```

컨트랙트 배포 + 공연 등록 + 지갑 생성 + 티켓 발행을 한 번만 하고, 그 뒤로 `TTL_SECONDS`(15초)마다 새 동적 코드를 생성·서명해서 터미널을 다시 그립니다 — 실제 앱 화면이 QR을 주기적으로 갱신하는 모습 그대로입니다.

**여기서 Enter를 누르면** 그 순간 화면에 떠있는 QR로 실제 게이트 스캔이 일어납니다: `ticketNFT.ownerOf`로 현재 소유자 조회 → `verifyEntryQr`로 검증 → 통과하면 `TicketNFT.markUsed` 호출까지. 검증에 실패하면(예: 회전 경계에 걸려 방금 막 만료됨) 이유를 출력하고 회전은 계속되므로 다음 회전 때 다시 Enter로 시도할 수 있고, 성공하면 회전을 멈추고 프로세스가 종료됩니다.

실제로는 유저 폰과 게이트 스캐너가 서로 다른 기기라 이 둘 사이를 파일/네트워크로 동기화해야 하지만, 이 데모는 하나의 프로세스 안에서 `currentPayload` 변수를 그대로 공유하는 방식으로 단순화했습니다 — 검증 로직(`verifyEntryQr`) 자체는 실제와 동일합니다.

### `scripts/demo/listTickets.ts` — 현재 존재하는 모든 티켓 상태 조회

```bash
npm run tickets:list -- --network localhost   # 반드시 --network localhost (영구 체인)로 실행
```

`TicketNFT`는 `ERC721Enumerable`을 상속하지 않습니다 — transfer할 때마다 추가 storage를 써야 하는 기능인데, 이 디버그 스크립트 말고는 쓸 데가 없어서 컨트랙트에 넣지 않기로 했습니다(다른 데모 스크립트들과 같은 판단 — 필요 이상으로 컨트랙트를 건드리지 않음). 대신 tokenId는 재사용/burn 없이 1부터 순서대로만 발급되므로, `tickets(tokenId)`를 1부터 순회하다가 처음으로 `status == NONE`(민팅된 적 없음)이 나오는 지점에서 멈추는 방식으로 전체 목록을 만듭니다.

- 어떤 컨트랙트를 조회할지는 `tmp/deployment.json`(위 배포 스크립트들이 실행마다 자동 기록)에서 읽어옵니다 — 그래서 `npm run seed`든 `npm run flow:demo`든, **가장 최근에 `--network localhost`로 실행한 것**의 티켓들이 나옵니다. 이 파일이 없으면(영구 노드에 아무것도 배포한 적 없으면) 무엇을 먼저 실행해야 하는지 에러 메시지로 안내합니다.
- 티켓마다 tokenId/공연(`showId`+`ShowRegistry`에서 조회한 `metadataURI`)/좌석/상태/정가/판매가(LISTED일 때만)/현재 소유자를 `console.table`로 출력하고, 마지막에 상태별 개수(`{ OWNED: 3, LISTED: 1, USED: 2, ... }`)를 집계해서 보여줍니다.
- 기본 하드햇 네트워크(매 실행마다 새로 뜨는 임시 체인)로 실행하면 항상 빈 체인이라 의미가 없습니다 — 반드시 `npx hardhat node`로 띄운 영구 `localhost` 네트워크에 다른 스크립트로 먼저 데이터를 만들어 둔 뒤 실행해야 합니다.

## 다음 단계 (미구현)

- 이벤트 인덱싱 인터페이스 정의 (백엔드가 미러 테이블에 반영할 이벤트 스펙)
- 등록 취소 페널티 로직 (스펙 미확정이라 보류 중)
- 공연 취소 시 발행된 티켓 일괄 회수·환불 오케스트레이션 (백엔드 쪽, 위 ShowRegistry 설명 참고)
- 백엔드 운영 계정들에 대한 나머지 role grant(OPERATOR_ROLE, GATE_ROLE 등)는 아직 배포 스크립트에 없음 — 필요해지면 `deploy.ts`에 추가
