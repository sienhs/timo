## 1. Java 코딩 컨벤션

### 1.1 패키지/클래스/메서드/변수 명명 규칙

1. **패키지명**
    - **소문자** 사용, 일반적으로 도메인 역순으로 구성.
    - 예: `com.example.myapp`
2. **클래스/인터페이스명**
    - **파스칼 케이스(PascalCase)** 사용.
    - 명사 형태, 인터페이스는 적용 패턴의 관례를 따름.
    - `able` /**`template`**
    - 예: `public class UserService`, `public interface Runnable`
3. **메서드명**
    - **카멜 케이스(camelCase)** 사용.
    - 동사 또는 동사구 형태, 역할을 명확히.
    - 예: `getUserById()`, `calculateTotalPrice()`
4. **변수명**
    - **카멜 케이스(camelCase)** 사용.
    - 의미가 명확하도록 작성, 축약형 지양.
    - 예: `int userCount`, `String firstName`
5. **상수명**
    - 모든 문자를 대문자로, 단어 간 구분은 언더스코어(`_`) 사용.
    - 예: `public static final int MAX_SIZE = 100;`
6. **DB**
    - **스네이크 케이스(snake_case)** 사용
    - DBMS예약어 사용 금지

### 1.2 들여쓰기/공백/중괄호

1. **들여쓰기**
    - 탭 권장.
2. **중괄호 위치**
    - K&R 스타일(**한 줄 위에 여는 중괄호**):

        ```java
        public void example() {
            // ...
        }
        ```

3. **띄어쓰기**
    - 연산자 주위에 공백 권장: `int sum = a + b;`
    - `if`, `for` 등의 키워드 뒤에 공백: `if (condition) { ... }`

### 1.3 주석(Comment)

1. **Javadoc 주석**
    - 클래스, 메서드, 필드에 대한 설명 사용:

        ```java
        /**
         * 사용자 정보를 반환합니다.
         *
         * @param id 사용자 ID
         * @return 사용자 객체
         */
        public User getUserById(Long id) { ... }
        ```

2. **라인 주석**
    - 불분명한 로직 또는 주의가 필요한 부분:

        ```java
        // 사용자 정보를 DB에서 조회
        User user = userRepository.findById(id);
        ```


### 1.4 기타 권장 사항

- **에러 처리**: 충분히 의미 있는 예외를 던지고, `try-catch` 시 구체적인 메시지 로그.
- **컬렉션 타입**: 제네릭(Generics)을 사용해 타입 안정성 보장.
- **코드 길이 제어**: 메서드가 너무 길어지지 않도록 분리해서 작성.

---

## 2. Spring 코드 컨벤션

### 2.1 패키지 구조

일반적으로 다음과 같은 **도메인 레이어 아키텍처**를 사용:

```
com.example.domain
 └─ users
		 ├─ Controller
		 ├─ Service
		 └─ Repository
 └─ config
 └─ global
```

- **Controller/Web**: HTTP 요청/응답 처리.
- **Service**: 비즈니스 로직 처리.
- **Repository/DAO**: 데이터베이스 접근.
- **Domain/Model/Entity**: 엔티티 클래스, VO, DTO 등.
- **Config**: 설정 관련 클래스.

### 2.2 클래스 및 어노테이션 규칙

1. **Controller** 클래스
    - `@RestController` 또는 `@Controller` 사용.
    - 요청 경로를 `@RequestMapping`(클래스 레벨) 또는 `@GetMapping`, `@PostMapping`(메서드 레벨)로 선언.
2. **Service** 클래스
    - `@Service` 사용.
    - 트랜잭션이 필요한 경우 `@Transactional` 부여.
3. **Repository** 클래스
    - `@Repository` 사용 또는 JPA에서는 `CrudRepository`, `JpaRepository` 등을 상속.
    - 데이터 접근 로직 구현.
4. **Entity** 클래스
    - `@Entity`, `@Table` 사용.
    - 필드는 `@Id`, `@Column`으로 매핑.

### 2.3 Bean 주입 방식

- **생성자 주입** 권장:

    ```java
    @Service
    public class UserService {
        private final UserRepository userRepository;
    
        public UserService(UserRepository userRepository) {
            this.userRepository = userRepository;
        }
        // ...
    }
    ```

- **필드 주입**은 테스트나 유지보수 관점에서 비추천.
- **Setter 주입**은 선택적인 의존성에만 사용.

### 2.4 예외 처리

- **ControllerAdvice**와 **@ExceptionHandler**를 사용하여 전역 예외 처리.
- 예외 발생 시 명확한 메시지와 상태 코드를 반환.

---

## 3. Spring Boot 코드 컨벤션

### 3.1 애플리케이션 구조

`com.example.demo`

```
com.timo
├── TimoApplication.java
├── global                   공통 기반
│   ├── config
│   ├── exception
│   ├── response
│   ├── security
│   └── util
├── domain                   업무 도메인 7개
│   ├── member
│   │   ├── controller
│   │   ├── service
│   │   ├── repository
│   │   ├── entity
│   │   └── dto
│   ├── wallet
│   ├── concert
│   ├── reservation
│   ├── ticket
│   ├── transfer
│   └── entry
└── chain                    온체인 연동
    ├── client
    ├── indexer
    ├── mint
    └── dto
```

- **메인 클래스**(예: `DemoApplication`)는 루트 패키지에 위치해 컴포넌트 스캔이 패키지 하위까지 적용되도록 함.

### 3.2 프로퍼티/설정 파일 관리

- **`application.yml`** 파일에 환경별 설정(`yml`) 구분 (`application-local.yml`, `application-prod.yml ,application-test.yml`등).
- 빈 설정은 최대한 `@ConfigurationProperties`를 사용해 명시적으로 관리.

### 3.3 자동 설정(Autoconfiguration)과 사용자 설정

- Spring Boot가 제공하는 **Auto Configuration**을 최대한 활용.
- 필요 시 **`@Configuration`** 클래스로 추가 설정.

### 3.4 로깅(Logging)

- Spring Boot는 기본적으로 **Logback** 사용.
- `application.yml`에서 로깅 레벨 설정:

---

## 4. 목록 조회 API 컨벤션

목록(페이지) 응답 규칙. 기준 구현은 `domain/concert` 의 `findAll` 계열이다.

### 4.1 응답

성공 응답은 공통 래퍼로 감싸지 않는다. 목록은 **`PagedModel<{도메인}SummaryResponseDto>`** 로 반환한다.
(2.1 구조도의 `global/response` 는 미구현이다. 봉투를 도입하면 기존 API 전부가 같이 바뀌므로 팀 합의 전까지 만들지 않는다.)

```json
{
  "content": [ { "id": 1, "title": "아이유 콘서트", "venueName": "고척돔" } ],
  "page": { "size": 20, "number": 0, "totalElements": 42, "totalPages": 3 }
}
```

- **`Page` 를 그대로 반환하지 않는다.** `pageable.offset` · `sort.empty` 같은 내부 필드가 노출되고,
  Spring Boot 가 직렬화 경고를 띄우며, 라이브러리 버전에 따라 모양이 바뀐다.
- **`first` / `last` 는 없다.** 마지막 페이지 여부는 클라이언트가 `number === totalPages - 1` 로 판단한다.
- 목록 항목은 `{도메인}SummaryResponseDto`, 상세는 `{도메인}DetailResponseDto` 로 이름 붙인다.

### 4.2 요청

- 조회 조건은 요청 DTO 하나로 묶어 `@Valid @ModelAttribute` 로 받는다. 검증 실패는 `400` 과
  `errors[{field, reason}]` 로 나간다(`MethodArgumentNotValidException`).
- 기본값은 `page=0` · `size=20`, `size` 상한은 **100**. 상한이 없으면 한 번의 요청으로 테이블 전체를 끌어갈 수 있다.
- 모든 조건은 선택값이다. 파라미터 없이 호출해도 첫 페이지가 나와야 한다.
- 문자열 검색어가 공백뿐이면 조건에서 뺀다. `like '%%'` 는 결과가 전체 조회와 같으면서 인덱스만 못 탄다.
- **`Pageable` 을 컨트롤러에서 직접 받지 않는다.** 리졸버가 `sort` 를 "필드명,방향" 으로 해석해 4.3 규약과 겹친다.

### 4.3 정렬

- 정렬 기준은 **enum 화이트리스트로만** 받는다. 필드명을 열어 두면 매핑되지 않는 속성일 때 `500` 이 나고,
  매핑되면 내부 모델 구조가 그대로 API 규약이 된다.
- **마지막에 유일 키(`id` 내림차순)를 덧붙인다.** 동점 행의 순서가 쿼리마다 달라지면 페이지를 넘길 때
  같은 행이 두 번 나오거나 아예 빠진다.
- 값이 비어 있을 수 있는 컬럼은 `nullsLast()` 를 붙인다. MySQL 에 해당 문법은 없지만 Hibernate 가
  `case when ... is null then 1 else 0 end` 로 바꿔 준다.
- 동점 키를 enum 의 `static final` 상수로 두지 않는다. enum 상수가 static 필드보다 먼저 초기화되어
  생성자에서 참조하면 `null` 이다.

### 4.4 조회 쿼리

- **다대일 연관만 `fetch join` 한다.** 컬렉션을 함께 걸면 행이 늘어 DB 에서 `limit` 을 걸 수 없고,
  Hibernate 가 전부 읽어 메모리에서 자른다.
- 그래서 **목록 응답에 컬렉션 필드를 담지 않는다.** 연관 목록은 상세 조회에서 준다.
  꼭 필요하면 페이지를 먼저 조회하고 그 id 목록으로 두 번째 쿼리를 날린다.
- `fetch join` 이 있는 페이지 쿼리는 **`countQuery` 를 직접 준다.** 자동 파생은 조인을 그대로 남겨
  불필요하게 무겁고, 실패할 수도 있다.
- 선택 조건은 `(:param is null or ...)` 로 처리한다.
- 목록 조회는 **부수 효과가 없어야 한다.** `@Transactional(readOnly = true)` 를 붙인다.
  조회수 증가 같은 것을 목록에서 하면 인기순 정렬이 "목록에 오래 노출된 순서"가 되어 버린다.

### 4.5 새 목록 API 체크리스트

- [ ] 응답이 `PagedModel<{도메인}SummaryResponseDto>` 인가
- [ ] `page` / `size` 기본값과 `size` 상한을 두었는가
- [ ] 정렬을 enum 으로 제한하고, 마지막에 유일 키를 덧붙였는가
- [ ] 컬렉션을 `fetch join` 하지 않고, `countQuery` 를 직접 주었는가
- [ ] `@Transactional(readOnly = true)` 이고 부수 효과가 없는가
- [ ] 정렬·필터를 실제 DB 로 검증하는 통합 테스트가 있는가

> 기준 구현: `ConcertController#findAll` · `ConcertServiceImpl#findAll` · `ConcertRepository#findPage` ·
> `ConcertListRequestDto` · `ConcertSortType` · `ConcertSummaryResponseDto`,
> 테스트 `ConcertListApiIntegrationTest` · `ConcertListRequestDtoTest`.
