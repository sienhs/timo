# TIMO Blockchain

TIMO의 티켓 발행·공식 리셀·예치 잔액을 처리하는 온체인 모듈입니다. 좌석별 전송 제한 NFT와 ERC-20 기반 서비스 잔액을 제공하며, 커스터디얼 지갑 및 입장 검증 모듈을 포함합니다.

## 기술 스택

| 구분 | 구성 |
|---|---|
| 스마트 컨트랙트 | Solidity 0.8.24, OpenZeppelin ERC721·ERC20·AccessControl |
| 개발·테스트·배포 | Hardhat 2.x, TypeScript, ethers.js v6 |
| 테스트 네트워크 | Hardhat 임시 네트워크, 별도 실행한 Hardhat 노드 |
| 공개 테스트넷 | Polygon Amoy |
| 서버 실행 | Docker Compose |

기존 설정과 테스트 호환성을 유지하기 위해 Hardhat 2.x를 사용합니다. Hardhat 3.x 전환은 별도 작업으로 관리합니다.

## 목차

- [시스템 구성](#시스템-구성)
- [로컬 실행](#로컬-실행)
- [EC2 실행과 로그 확인](#ec2-실행과-로그-확인)
- [컨트랙트와 거래 규칙](#컨트랙트와-거래-규칙)
- [커스터디얼 지갑](#커스터디얼-지갑)
- [입장 검증](#입장-검증)
- [스크립트](#스크립트)
- [테스트](#테스트)
- [운영 설정과 주의사항](#운영-설정과-주의사항)
- [미구현 및 확인 필요 사항](#미구현-및-확인-필요-사항)

## 시스템 구성

### 결제와 자산

| 구성 요소 | 역할 |
|---|---|
| PG 결제 | 오프체인 결제 확인. 현재 백엔드는 PG 모의 연동 단계 |
| `TicketVault` | 앱에서 사용하는 ERC-20(`MSR`, Mushroom) 잔액 관리 및 충전·차감·환불·리셀 정산 |
| `TicketNFT` | 좌석별 NFT 소유권과 티켓 상태 관리 |
| `Marketplace` | 공식 리셀의 티켓 이전과 잔액 정산을 단일 트랜잭션으로 실행 |

`MSR`(Mushroom)는 서비스 결제용 잔액이며 가스 토큰과 구분됩니다. 현재 구조에서는 운영자 지갑이 네이티브 코인으로 가스비를 지급하고, 권한이 부여된 컨트랙트 함수를 호출합니다.

사용자 지갑은 서버가 생성·암호화 보관하는 EOA입니다. 현재 설계에서 사용자 개인키는 입장 QR의 오프체인 메시지 서명에 사용하며, 해당 서명 자체에는 가스비가 발생하지 않습니다.

### 네트워크 구분

| 환경 | 용도 | 상태 유지 |
|---|---|---|
| Hardhat 내장 임시 네트워크 | 단위 테스트, 독립적인 스크립트 실행 | 실행 종료 시 초기화 |
| `localhost` Hardhat 노드 | 여러 프로세스가 공유하는 개발·통합 테스트 | 노드 실행 중 유지, 재시작 시 초기화 |
| Polygon Amoy | 공개 테스트넷 연동 및 데모 검증 | 로컬 프로세스 종료와 별개로 네트워크에서 관리 |

`localhost`는 영구 저장 체인이 아닙니다. Docker로 실행해도 Hardhat의 인메모리 상태는 재시작 시 초기화됩니다.

## 로컬 실행

모든 명령은 저장소의 `blockchain/` 디렉터리를 기준으로 합니다.

### 1. 의존성 및 환경 설정

```bash
npm ci
```

최초 설정 시 `.env.example`을 복사합니다. 기존 `.env`가 있다면 덮어쓰지 않고 필요한 항목을 확인합니다.

```bash
cp .env.example .env
```

| 환경변수 | 용도 |
|---|---|
| `ADMIN_PRIVATE_KEY` | 컨트랙트 배포 및 관리자 권한을 사용하는 서명 계정 |
| `WALLET_MASTER_KEY` | 지갑별 DEK를 암복호화하는 32바이트 마스터키. 64자리 16진수 형식 |

마스터키 생성:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### 2. 컴파일 및 테스트

```bash
npm run compile
npm test
```

### 3. 공유 노드 실행 및 배포

첫 번째 터미널에서 노드를 실행합니다.

```bash
npm run node -- --hostname 127.0.0.1 --port 8545
```

다른 터미널에서 실행 중인 노드에 배포합니다.

```bash
npm run deploy -- --network localhost
```

지속 실행 중인 노드를 대상으로 하는 스크립트에는 `--network localhost`를 지정합니다. Amoy 배포는 해당 네트워크 설정과 가스 잔액을 준비한 뒤 `--network amoy`를 사용합니다.

## EC2 실행과 로그 확인

```bash
cd blockchain
docker compose up -d --build
```

```bash
docker compose ps
docker logs --tail 100 -f --timestamps timo-hardhat
```

Docker가 로그를 관리하므로 SSH 연결을 종료한 뒤에도 다른 세션에서 조회할 수 있습니다.

### 컨테이너 시작 과정

1. 빌드 단계에서 의존성을 설치하고 컨트랙트를 컴파일합니다.
2. `docker/entrypoint.sh`가 `hardhat node --hostname 0.0.0.0`을 실행합니다.
3. RPC 응답을 확인한 뒤 `scripts/deploy/deploy.ts`를 `localhost` 대상으로 실행합니다.
4. 컨트랙트 4개를 배포하고 배포 스크립트에 정의된 권한을 부여합니다.

컨테이너는 공연 시드를 등록하지 않습니다. 로컬 백엔드의 `LocalDataSeeder`가 web3j의 `ShowRegistryClient`를 통해 공연을 등록합니다.

| 항목 | 설정 |
|---|---|
| 재시작 정책 | `unless-stopped` |
| 로그 드라이버 | `json-file` |
| 로그 크기·파일 수 | `max-size: 10m`, `max-file: 5` |

### 재시작 시 확인 사항

컨테이너가 재시작되면 공연·NFT·잔액·거래 이력이 초기화됩니다. 자동 재배포는 컨트랙트를 다시 생성하는 것이며 기존 상태를 복원하지 않습니다.

- 공유 체인 재시작은 팀에 먼저 알립니다.
- DB의 `showId`, `tokenId`, 정산 상태와 새 체인의 상태가 일치하는지 확인합니다.
- 로컬 시더는 DB가 비어 있을 때 실행하는 구조이므로, 백엔드 재시작만으로 공연이 재등록된다고 가정하지 않습니다.
- 테스트 DB를 초기화하거나 별도 재등록 절차로 온체인 상태와 다시 맞춥니다.

## 컨트랙트와 거래 규칙

### 컨트랙트 구성

| 컨트랙트 | 역할 | 주요 권한 |
|---|---|---|
| `ShowRegistry` | 공연별 구역당 정가(5구역 고정), 좌석 수, 판매·공연 시각 관리 | `ORGANIZER_ROLE`, `OPERATOR_ROLE` |
| `TicketNFT` | 좌석별 전송 제한 ERC-721 | `ORGANIZER_ROLE`, `MARKETPLACE_ROLE`, `OPERATOR_ROLE`, `GATE_ROLE` |
| `TicketVault` | ERC-20(`MSR`, Mushroom) 기반 예치 잔액과 정산 | `OPERATOR_ROLE`, `MARKETPLACE_ROLE` |
| `Marketplace` | `buy`를 통한 리셀 이전·정산 | `OPERATOR_ROLE` |

### 티켓 이전 및 소유 제한

- `TicketNFT._update`는 `auth != address(0)`인 호출을 거부합니다. 내부 발행·이전·회수·재발행 경로에서만 `auth = address(0)`으로 상태를 변경합니다.
- 공개 `transferFrom` 계열과 `approve`, `setApprovalForAll`을 차단하여 지정된 거래 경로로만 이전하도록 제한합니다.
- `holdsShow[address][showId]`로 발행·리셀 이전·재발행 시 주소별 공연당 1매 제한을 적용합니다. 실제 사람 기준의 제한은 백엔드의 본인확인·지갑 연결 정책과 함께 보장해야 합니다.
- `(showId, seatId)`마다 tokenId 하나를 사용합니다. 취소 후에는 `revoke`·`reissue`로 같은 토큰을 재사용합니다.
- 발행 가격은 호출자가 전달하지 않고, 호출자가 지정한 `sectionIndex`(0-4)로 `ShowRegistry.facePriceOf(showId, sectionIndex)`에서 조회합니다 - 호출자가 고를 수 있는 건 "어느 구역이냐"뿐이고 그 구역의 가격 자체를 조작할 방법은 없습니다.

### 구역별 정가 (`ShowRegistry.SECTION_COUNT = 5`)

이 시스템의 모든 공연장은 구역 5개로 고정입니다. `Show.sectionPrices`는 `uint256[5]` 고정 배열이고, 인덱스는 공연장 구역을 **id 오름차순**으로 나열한 순서와 일치해야 합니다(백엔드 `SectionRepository.findAllByVenueIdOrderByIdAsc`가 그 순서를 보장 - `SectionRepository`의 자체 문서 참고).

- `registerShow`/`updateShow`는 5개 가격을 전부 받고, 하나라도 0이면 `InvalidPrice`로 거부합니다.
- `facePriceOf(showId, sectionIndex)` — 구역 하나의 가격만 조회(`TicketNFT.mintTicket`이 씀). `sectionIndex >= 5`면 `InvalidSectionIndex`.
- `sectionPricesOf(showId)` — 5개 전부 한 번에 조회.
- Solidity의 구조체 자동 getter는 배열 필드를 반환값에서 생략합니다 - `shows(showId)`로는 가격을 못 읽고 위 두 함수를 써야 합니다.
- 이전 버전은 공연당 정가가 하나였는데, "구역마다 가격이 다르다"는 실제 요구사항에 맞춰 이 구조로 바뀌었습니다. 프론트엔드는 이 변경과 무관합니다 - 백엔드가 이미 갖고 있던 `Section.price`를 그대로 온체인에 실어 올리는 것뿐입니다.

### 잔액과 정산

`TicketVault`는 ERC-20 조회 인터페이스를 제공하지만 일반적인 자유 전송 토큰은 아닙니다.

- `transfer`, `approve`, `transferFrom`을 차단합니다.
- 잔액 변경은 `deposit`, `chargeForBooking`, `refund`, `settleTransfer` 내부 경로로 제한합니다.
- `balanceOf`, `totalSupply`, `Transfer` 이벤트를 제공하며, 주문·거래 식별자는 `ChargedForBooking` 등 별도 이벤트로 추적합니다.
- 1차 예매 차감과 리셀 정산은 동일한 온체인 잔액을 사용합니다. 먼저 잔액을 소비한 거래가 있으면 이후 거래는 잔액 부족으로 실패할 수 있습니다.
- DB의 예매 접수·상태 변경은 온체인 정산과 별개이므로, 백엔드에서 실패 보상과 상태 동기화를 처리해야 합니다.

### 원자적 리셀과 중복 처리 방지

`Marketplace.buy`는 NFT 이전과 Vault 정산을 하나의 트랜잭션에서 실행합니다. 한쪽이 실패하면 전체가 롤백됩니다. 이를 위해 Marketplace 주소에 두 컨트랙트의 `MARKETPLACE_ROLE`이 부여돼 있어야 합니다.

Vault의 잔액 변경 함수는 소비형 `refId(bytes32)`로 중복 요청을 거부합니다. 이미 사용한 ID로 재호출하면 `DuplicateOperation`이 발생합니다. 백엔드는 이를 최초 처리 실패와 구분하고 기존 거래 결과를 확인해야 합니다.

### 환불

`refund(user, organizer, amount, refId)`는 주최자 잔액을 사용자에게 이전합니다. 새로운 잔액을 발행하는 방식이 아니므로 주최자 잔액이 부족하면 환불도 실패합니다.

백엔드는 `Concert.organizer` 등을 통해 정산 대상 주최자를 식별하고, 환불 실패 시 재처리 또는 수동 확인이 가능하도록 상태를 기록해야 합니다.

## 커스터디얼 지갑

구현 위치: `src/wallet/custodialWallet.ts`

`createCustodialWallet(userId)`는 다음 순서로 지갑을 생성합니다.

1. EOA 키페어와 주소 생성
2. 지갑별 32바이트 DEK 생성
3. DEK를 사용해 Ethereum V3 keystore(scrypt) 생성
4. 마스터키와 AES-256-GCM으로 DEK 래핑

호출자에게 평문 개인키와 DEK를 반환하지 않습니다. AES-256-GCM 인증 검증은 잘못된 키나 래핑 데이터 변조를 탐지합니다.

### 보호 범위

지갑별 DEK 분리는 개별 DEK 유출의 영향을 해당 지갑으로 제한하고 키 관리를 분리하는 데 도움이 됩니다. **마스터키와 각 지갑의 암호화 데이터가 함께 유출되면 전체 지갑이 위험할 수 있습니다.**

현재 마스터키는 `.env` 또는 Secrets Manager를 통해 공급합니다. 이는 메모리 내 평문 키 사용까지 제거하지 않으며, KMS 전환 시에는 키 조회뿐 아니라 DEK 래핑·언래핑 방식과 접근 권한도 검토해야 합니다.

## 입장 검증

구현 위치: `src/entry/entryVerification.ts`

동적 코드와 지갑 서명을 결합하며, `verifyEntryQr`는 다음 조건을 모두 만족할 때 `allowed: true`를 반환합니다.

| 검증 항목 | 기준 |
|---|---|
| 만료 | `now <= expiresAt`, 기본 TTL 15초 |
| 재사용 | 소비되지 않은 코드인지 확인하고 성공 시 소비 처리 |
| 소유권 | 서명 복구 주소와 스캔 시점의 `ownerOf(tokenId)` 비교 |

`currentOwner`와 `consumedCodes`는 호출자가 제공합니다. 서비스 연동 시에는 최신 소유권을 조회하고, 여러 게이트가 공유하는 저장소에서 코드 확인·소비를 원자적으로 처리해야 합니다. 실제 입장 완료 상태 전이와의 연계도 별도로 확인합니다.

## 스크립트

| 명령 | 실행 파일 | 용도 |
|---|---|---|
| `npm run compile` | Hardhat compile | 컨트랙트 컴파일 |
| `npm test` | Hardhat test | 단위 테스트 |
| `npm run node` | Hardhat node | 별도 개발 노드 실행 |
| `npm run deploy -- --network localhost` | `scripts/deploy/deploy.ts` | 컨트랙트 4개 배포 및 권한 설정 |
| `npm run seed -- --network localhost` | `scripts/seed/seedDummyShows.ts` | 레거시 수동 데모: 배포 및 더미 주최사·공연 6개 등록 |
| `npm run wallet:create` | `scripts/demo/createUserWallet.ts` | 지갑 생성 및 주소·keystore 출력 |
| `npm run flow:demo` | `scripts/demo/fullUserFlow.ts` | 지갑 생성·충전·예매·입장 검증 및 QR 이미지 생성 |
| `npm run qr:live` | `scripts/demo/liveEntryQr.ts` | QR 갱신과 게이트 스캔 시연 |
| `npm run mint:seeded -- --network localhost` | `scripts/demo/mintTicketForUser.ts` | 등록된 공연에 특정 사용자 티켓 발행 |
| `npm run tickets:list -- --network localhost` | `scripts/demo/listTickets.ts` | 배포된 티켓 상태 조회 |

- `mint:seeded`는 `SHOW_ID`, `SEAT_ID`, `USER_ID` 환경변수를 사용합니다.
- `deployContracts`는 배포 주소를 `tmp/deployment.json`에 기록합니다. `tickets:list` 등 후속 스크립트는 해당 파일을 참조하므로 대상 네트워크·배포와 일치하는지 확인합니다.
- 레거시 시드 데이터는 `seed-data/dummy-shows.json`에서 관리하며, 기존 시드 흐름은 배열 순서와 온체인 showId의 대응을 전제로 합니다.
- `seedDummyShows.ts`는 컨테이너 자동 실행 및 백엔드 시딩에서 사용하지 않습니다.

## 테스트

기존 검증 기록 기준 총 101개 테스트가 통과했습니다. 현재 체크아웃의 결과는 `npm test`로 확인합니다.

| 대상 | 테스트 수 |
|---|---:|
| ShowRegistry | 29 |
| TicketNFT | 30 |
| TicketVault | 22 |
| Marketplace | 5 |
| 커스터디얼 지갑 | 9 |
| 입장 검증 | 6 |
| 합계 | 101 |

Hardhat 단위 테스트 결과는 공개 네트워크의 처리량이나 최종 확정 시간을 보장하지 않습니다.

## 운영 설정과 주의사항

### 배포 주소 계산

현재 배포 순서는 `ShowRegistry`, `TicketNFT`, `TicketVault`, `Marketplace`입니다. 백엔드 `DeployedContractAddresses`(`global/config`)는 `Web3jConfig`가 검증해 둔 admin 자격증명과 예상 배포 nonce를 기준으로 컨트랙트 주소를 계산합니다.

`CREATE` 주소가 같으려면 **배포 계정과 각 컨트랙트 생성 시점의 nonce가 동일해야 합니다.** 초기화된 체인에서 같은 절차로 배포하면 주소가 재현될 수 있지만, 다음 경우에는 달라질 수 있습니다.

- 관리자 키 또는 배포 순서 변경
- 배포 전이나 컨트랙트 생성 사이에 추가 트랜잭션 실행
- 초기화하지 않은 체인에서 재배포
- 배포 스크립트의 생성 방식 변경

배포 절차를 수정하면 백엔드의 주소 계산 전제도 함께 확인합니다. 주소가 같더라도 재시작 전의 상태가 복원되는 것은 아닙니다.

### 시크릿 관리

| 사용처 | 공급 방식 |
|---|---|
| 백엔드 EC2 | Secrets Manager 값을 `infra/modules/ec2` 부팅 스크립트가 읽어 `/etc/timo/backend.env` 생성 |
| 블록체인 EC2 | 별도 `.env` 파일 사용. Git 추적 대상에서 제외 |

현재는 블록체인 배포와 백엔드 서명이 동일한 `ADMIN_PRIVATE_KEY`를 사용하는 구성입니다. 값이 달라지면 주소 계산 또는 권한 검증이 실패할 수 있습니다.

`WALLET_MASTER_KEY`는 Terraform 변수로 관리하지만 `ADMIN_PRIVATE_KEY`는 Secrets Manager에 수동 등록한 상태입니다. Terraform이 관리하는 시크릿 값에 해당 키가 누락돼 있으면 이후 갱신에서 유실될 수 있으므로 코드 관리 범위에 포함해야 합니다.

### RPC 접근 제어

`0.0.0.0` 바인딩은 외부 연결을 수신하기 위한 설정이며 인증 수단이 아닙니다. 공유 RPC(`network.ticketmoa.site:8545`)는 백엔드 NAT 공인 IP 등 필요한 출처로 접근을 제한합니다.

Hardhat은 공개된 테스트 개인키, 잠금 해제 계정, 개발용 상태 제어 RPC를 제공합니다. **별도 관리자 키를 지정해도 RPC 자체가 안전해지는 것은 아닙니다.** 공유 환경에서는 `ADMIN_PRIVATE_KEY`를 명시하고 네트워크 접근 제한을 함께 적용합니다.

## 미구현 및 확인 필요 사항

- 백엔드 미러 테이블을 위한 이벤트 인덱싱 인터페이스
- 양도 등록 취소 페널티: 요율 미확정, 현재 `delistFor()`는 상태만 변경
- 공연 취소 시 티켓 일괄 회수·환불 처리: ShowRegistry의 D-7 취소 처리와 별개
- `ADMIN_PRIVATE_KEY`의 Terraform 시크릿 관리 반영
- 구역 가격(`Section.price`, 원화 정수)을 온체인 금액 단위(그 자체는 그냥 `uint256`이지만 `TicketVault`/`deposit` 등 다른 곳에서 통상 wei 스케일로 다뤄온 값들과) 어떻게 맞출지 - 지금은 원화 정수를 그대로 싣습니다

권한 부여의 실제 범위는 `scripts/deploy/deploy.ts`를 기준으로 확인합니다. 관리자 권한과 Marketplace 컨트랙트에 부여하는 권한을 구분하여 점검합니다.
