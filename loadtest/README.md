# 동시 활성 사용자 한계 측정

앱 `t3.medium` + 전용 MySQL RDS만 테스트할 때 생성하고, k6는 로컬 컴퓨터에서 실행한다. 발생기 EC2 비용은 없다.
기존 VPC/서브넷/ECR을 참조하고 독립 local state를 사용한다. 운영 Terraform 루트에서 apply/destroy하지 않는다.
기존 측정치는 폐기했다. 이번 결과는 **예매 진입 흐름 + 회차마다 2초 대기** 기준이며 ALB·로그인·결제·블록체인 처리량은 포함하지 않는다.

## 자동 실행

아래 한 명령이 현재 AWS 운영 인프라의 `ticketing-dev-*` 태그를 읽어 테스트 `terraform.tfvars`를 생성하고, 최신 ECR 이미지 digest를 고정한 뒤 `apply → 더미 데이터 준비 → 스모크 → 워밍업 → 50/100/200/400/800명 측정 → destroy`를 실행한다.

```powershell
.\loadtest\Invoke-LoadTest.ps1
```

PowerShell 실행 정책을 바꾸고 싶지 않으면 [Run-LoadTest.cmd](C:/Users/조영진/S15P21D206/loadtest/Run-LoadTest.cmd)를 더블클릭하거나 아래처럼 실행한다. `AWS_PROFILE`이 비어 있을 때만 `tiketing-dev`를 사용한다.

```powershell
.\loadtest\Run-LoadTest.cmd
```

CMD 런처는 Codex Desktop에 포함된 Node.js를 자동으로 사용한다. k6가 PATH에 없을 때는 Grafana의 고정된 `v1.6.1` 공식 릴리스를 `loadtest/.tools`에 한 번 내려받아 현재 실행에 사용한다. 이 폴더는 Git에 포함되지 않는다.

기본값은 각 단계 5분이고, 첫 SLO 실패 단계에서 중단한다. 테스트 완료·실패·중단 후에도 `finally`에서 테스트 EC2와 RDS를 삭제한다. 자원을 남겨 재실행하려면 `-KeepInfrastructure`를 사용하며, 종료 후 수동 destroy가 필요하다.

```powershell
.\loadtest\Invoke-LoadTest.ps1 -UserLevels 50,100,200 -Duration 3m
.\loadtest\Invoke-LoadTest.ps1 -KeepInfrastructure
```

자동 생성되는 [infra/loadtest/terraform.tfvars](C:/Users/조영진/S15P21D206/infra/loadtest/terraform.tfvars)는 현재 공인 IP `/32`, 기존 VPC/서브넷, 운영 RDS 엔진·클래스, 앱 CPU credit 모드, 최신 ECR digest를 담는다. DB 비밀번호는 매번 임의 생성해 현재 PowerShell 프로세스에만 주입한다. 두 파일 모두 Git에 무시된다. 운영 RDS와 운영 앱에는 데이터를 쓰지 않는다.

## 수동 실행

필요 도구: Terraform >= 1.8, Node.js, 로그인된 AWS CLI, 로컬 k6(기준 버전 1.6.1). `k6 version`으로 PATH 등록을 확인한다. 로컬 Docker/Python은 필요 없다.
AWS 계정에는 테스트 인프라 생성/삭제, SSM 명령 실행, CloudWatch 조회 권한이 필요하다.

자동 탐색이 맞지 않는 계정/환경에서만 `infra/loadtest/terraform.tfvars.example`을 같은 폴더의 `terraform.tfvars`로 복사해 값을 직접 입력한다. DB 파라미터 그룹은 현재 기본 그룹을 전제로 한다. 운영이 커스텀 그룹이면 같은 설정을 먼저 반영한다.

```powershell
$env:TF_VAR_db_password = 'Replace-With-New-Test-Password-123'
terraform -chdir=infra/loadtest init
terraform -chdir=infra/loadtest plan
terraform -chdir=infra/loadtest apply
# AWS Systems Manager에서 앱 인스턴스가 Online이 된 후
node loadtest/run.mjs prepare
```

로컬 k6 → 앱 public IP:8080 → 전용 RDS로 요청한다. 앱 8080은 지정한 로컬 공인 IP에서만, DB 3306은 앱 SG에서만 접근한다. 테스트 전용 계정으로 HTTP 요청을 보내며, 지연 측정에는 로컬 인터넷 왕복 시간이 포함된다. NAT·ALB·DNS·별도 모니터링 서버는 생성하지 않는다.
`prepare`는 **빈 timo_loadtest DB만** 초기화하고 운영 스키마, 계정 2,000개, 20개 구역 × 100개 좌석을 넣는다. 각 VU는 같은 번호의 계정과 좌석을 사용한다. 중간 실패 후 재준비는 destroy/apply부터 한다.

동일 운영 이미지를 사용하되 테스트 전용 키·DB를 주입하고, FCM/트레이싱을 끄며, 블록체인은 localhost로 차단한다. 30분 확인을 위해 access token TTL만 2시간으로 늘린다. 운영에 별도 JVM/컨테이너 제한이 생기면 `prepare.sh`에도 동일하게 적용한다. 테스트 DB 비밀번호는 Terraform local state와 SSM 명령 이력에 남으므로 운영 비밀번호를 사용하지 않는다. state는 destroy 완료까지 보관한다.

## 실행

```powershell
node loadtest/run.mjs run 1 30s    # 스모크: API/인증/시드 확인
node loadtest/run.mjs run 50 3m   # 워밍업: 수용량 판정에서 제외
node loadtest/run.mjs run 50 5m
node loadtest/run.mjs run 100 5m
node loadtest/run.mjs run 200 5m
# 통과한 경우에만 400, 800, 1600 순서로 증가
# 최초 실패 시 직전 통과 인원과 실패 인원 사이를 좁혀 재실행
node loadtest/run.mjs run 150 30m # 예시: 최종 후보 확인, 150명은 측정값이 아님
```

한 번에 하나만 실행한다. 로그인은 각 실행의 setup에서 제외되어 수행된다. 실행 간 해제 실패가 있으면 최소 5분 기다리고 스모크를 다시 확인한다. 동일 조건 비교 실험은 DB를 새로 생성해 시작한다(선점 이력 등 데이터가 누적됨).
현재 시드 상한은 2,000명이다. 상한까지 통과하면 "2,000명 이상 수용 확인"으로 기록하며 최대라고 단정하지 않는다.

구간별 합격 기준은 성공률 >=99%, 흐름 p95 <=3초, 선점 p95 <=1.5초, 완료 흐름 >0이다. 실패·타임아웃도 흐름 성공률에 포함하고 실패 후에도 2초 쉰다. 구간마다 독립 k6 실행이므로 워밍업/다른 구간 평균이 섞이지 않는다. 종료 코드 2는 측정 기준 실패, 그 밖의 오류는 실행 문제다.

## 매번 문서화

`loadtest/results/<시간>-<인원>vu/`에 자동 저장된다.

- `report.md`: 조건·성공률·p95·flows/s·통과/실패 한 표. **병목과 최종 판단 두 줄만 직접 작성**한다.
- `summary.json`: 판정 지표 원본.
- `http-status.json`: API·HTTP 상태 코드별 요청 수. 실패 원인을 먼저 여기서 확인한다. `k6-raw.json`은 이 집계의 원본 요청 이벤트다. 로그인 토큰은 결과에 저장하지 않는다.
- `app-log-tail.txt`: k6 종료 직후 SSM으로 수집한 앱 컨테이너 최근 로그와 메모리 사용량. 5xx가 있으면 이 파일을 함께 확인한다.
- `config.json`: 이미지 digest, 인프라 식별자, 로컬 OS/CPU/메모리/k6 버전.
- `cloudwatch.json`: 앱 CPU, CPU credit, DB CPU/연결 수. CloudWatch 수집 지연 때문에 마지막 구간이 누락될 수 있다.

테스트 중 로컬 작업 관리자에서 CPU·메모리·네트워크 포화를 확인한다. 같은 컴퓨터와 네트워크를 사용하고 VPN·대용량 다운로드·절전 모드를 피한다. CloudWatch로 앱/DB 자원을 확인하고, 앱 SSM 세션에서 `docker stats timo-loadtest`와 `free -m`으로 메모리를 관찰한다. 발생기 포화·OOM·토큰 오류가 있다면 해당 결과로 서버 한계를 확정하지 않는다. 최종 후보를 30분 유지해서 통과한 인원만 "30분 검증 동시 활성 사용자 N명"으로 기록한다. T3 standard의 크레딧 소진 전 결과는 지속 수용량으로 단정할 수 없고, unlimited는 초과 CPU 비용이 생길 수 있다.

결과는 기본 gitignore 대상이다. 공유할 보고서만 `git add -f loadtest/results/<폴더>/report.md`로 커밋한다.

## 종료

```powershell
terraform -chdir=infra/loadtest destroy
```

실패한 실행 후에도 종료 시 반드시 destroy한다. 자동 삭제하지 않으므로 여러 구간을 같은 서버에서 측정할 수 있다. 중단 시 로컬 k6 프로세스가 종료됐는지 확인한다. prepare 중단 시에는 원격 SSM 명령이 계속 돌 수 있으므로 상태를 확인한다. 앱 EC2·RDS·public IPv4·데이터 전송 등 AWS 비용은 테스트 환경 유지 중 발생한다.

## 로컬 검증

```powershell
terraform -chdir=infra/loadtest fmt -check
terraform -chdir=infra/loadtest validate
node --check loadtest/run.mjs
node loadtest/verify.mjs
```

실제 AWS apply/DB 초기화/k6 실행은 별도 실환경 검증이 필요하다.
