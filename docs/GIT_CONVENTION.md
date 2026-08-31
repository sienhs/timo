# Git Flow & 커밋 컨벤션

팀 공통 Git 작업 규칙 문서입니다. 브랜치 전략, 커밋 메시지 규칙, MR(Merge Request) 머지 규칙 문서 입니다.

---

## 1. 브랜치 전략

| 브랜치 | 역할 | 병합 방향 |
| --- | --- | --- |
| `master` | 릴리스 브랜치. 릴리스 시점의 안정 버전을 태깅/보관 | ← `development` |
| `development` | 실 배포 브랜치. 작업이 통합되어 실제로 배포됨 | ← `feature/*`, `refactor/*` |
| `feature/*` | 기능 개발 단위 브랜치 | → `development` |
| `refactor/*` | 리팩터링 단위 브랜치 | → `development` |
| `hotfix/*` | 긴급 수정 | → `master`, `development` |

- 평소 작업은 `development`에 통합되어 배포됩니다.
- 릴리스 시점에 `development` → `master`로 병합하고 버전 태그(`v1.0.0` 등)를 붙입니다.

**브랜치 이름 규칙**

```
feature/로그인-소셜연동
feature/123-user-profile      # 이슈 번호 포함 권장
refactor/결제모듈-정리
hotfix/토큰-만료-버그
```

- 소문자, 하이픈(`-`)으로 단어 구분
- 이슈 트래커를 쓴다면 `feature/{이슈번호}-{설명}` 형식 권장

---

## 2. 커밋 메시지 컨벤션

작업 브랜치에 쌓는 개별 커밋은 아래 형식으로 작성합니다.

```
<type>: <메시지>
```

- `type`은 **소문자**, 콜론(`:`) 뒤에 **한 칸 띄우고** 메시지 작성
- 메시지는 무엇을 했는지 간결하게(권장 50자 이내)

### 타입 정의

| type | 설명 |
| --- | --- |
| `feat` | 새로운 기능 추가 |
| `env` | 환경 설정 변경 (빌드, 배포, 설정 파일, 의존성 등) |
| `chore` | 기타 잡무성 작업 (문서, 주석, 사소한 정리 등) |

> 필요에 따라 아래 타입도 함께 사용할 수 있습니다. 팀 상황에 맞게 추가/삭제하세요.
>
> | type | 설명 |
> | --- | --- |
> | `fix` | 버그 수정 |
> | `refactor` | 기능 변화 없는 코드 개선 |
> | `style` | 코드 포맷팅, 세미콜론 등 (동작 변화 없음) |
> | `test` | 테스트 코드 추가/수정 |
> | `docs` | 문서 수정 |

### 예시

```
feat: 카카오 소셜 로그인 추가
feat: 사용자 프로필 이미지 업로드 기능 구현
env: 프로덕션 환경변수 설정 추가
env: eslint 규칙 업데이트
chore: 사용하지 않는 import 제거
chore: README 오타 수정
```

---

## 3. MR 머지 컨벤션

MR(Merge Request)을 통해 **상위 브랜치로 머지**할 때의 머지 커밋 메시지 규칙입니다.
개별 커밋과 구분하기 위해 **대괄호 접두사**를 사용합니다.

```
[Prefix] <머지 커밋 메시지>
```

### 접두사 정의

| Prefix | 설명 |
| --- | --- |
| `[Feature]` | 기능 개발 MR |
| `[Refactor]` | 리팩터링 MR |

> 확장이 필요하면 아래처럼 대응시켜 사용할 수 있습니다.
>
> | Prefix | 설명 |
> | --- | --- |
> | `[Fix]` | 버그 수정 MR |
> | `[Hotfix]` | 운영 긴급 수정 MR |
> | `[Env]` | 환경/설정 관련 MR |

### 예시

```
[Feature] 소셜 로그인 전체 기능 추가
[Feature] 사용자 프로필 관리 기능
[Refactor] 결제 모듈 구조 개선
[Refactor] 인증 로직 중복 제거
```

---

## 4. 전체 흐름 요약

```
1. development 에서 작업 브랜치 생성
   git checkout development
   git pull
   git checkout -b feature/소셜로그인

2. 작업하며 커밋 (커밋 컨벤션 준수)
   git commit -m "feat: 카카오 소셜 로그인 추가"
   git commit -m "env: 소셜 로그인 관련 환경변수 추가"

3. 원격 푸시 후 MR 생성 (development ← feature/소셜로그인)
   git push origin feature/소셜로그인

4. 리뷰 후 머지 → development 배포 (머지 커밋 컨벤션 준수)
   [Feature] 소셜 로그인 전체 기능 추가

5. 릴리스 시점에 development → master 병합 + 태깅
   [Feature] v1.1.0 릴리스
   git tag v1.1.0
```

---

## 5. 체크리스트

**커밋 전**
- [ ] 커밋 타입(`feat` / `env` / `chore`)이 작업 내용과 맞는가
- [ ] 메시지가 간결하고 명확한가
- [ ] 한 커밋에 하나의 논리적 변경만 담겼는가

**MR 생성 시**
- [ ] 대상 브랜치가 올바른가 (`development`, 릴리스 시 `master`)
- [ ] MR 제목이 `[Feature]` / `[Refactor]` 접두사 규칙을 따르는가
- [ ] 리뷰어를 지정했는가