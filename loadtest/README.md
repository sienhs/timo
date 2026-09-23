# 동시 활성 사용자 한계 측정

앱 `c7i.xlarge` 6대 + 전용 MySQL RDS만 테스트할 때 생성하고, k6는 로컬 컴퓨터에서 실행한다. 발생기 EC2 비용은 없다.
기존 VPC/서브넷/ECR을 참조하고 독립 local state를 사용한다. 운영 Terraform 루트에서 apply/destroy하지 않는다.
기존 측정치는 폐기했다. 이번 결과는 **예매 진입 흐름 + 회차마다 2초 대기** 기준이며 ALB·로그인·결제·블록체인 처리량은 포함하지 않는다.

## 자동 실행

아래 한 명령이 현재 AWS 운영 인프라의 `ticketing-dev-*` 태그를 읽어 테스트 `terraform.tfvars`를 생성하고, 최신 ECR 이미지 digest를 고정한 뒤 `apply → 더미 데이터 준비 → 스모크 → 워밍업 → 지정 사용자 수 측정 → destroy`를 실행한다.

```powershell
.\loadtest\Invoke-LoadTest.ps1
```

PowerShell 실행 정책을 바꾸고 싶지 않으면 [Run-LoadTest.cmd](C:/Users/조영진/S15P21D206/loadtest/Run-LoadTest.cmd)를 더블클릭하거나 아래처럼 실행한다. `AWS_PROFILE`이 비어 있을 때만 `tiketing-dev`를 사용한다.

```powershell
.\loadtest\Run-LoadTest.cmd
```

CMD 런처는 Codex Desktop에 포함된 Node.js를 자동으로 사용한다. k6가 PATH에 없을 때는 Grafana의 고정된 `v1.6.1` 공식 릴리스를 `loadtest/.tools`에 한 번 내려받아 현재 실행에 사용한다. 이 폴더는 Git에 포함되지 않는다.

기본값은 10,000명·35분, 최초 유입 10초 분산, `active-limit=400` 단일 검증이다. 여러 제한값을 비교하려면 `-QueueActiveLimits 200,400,800`을 명시한다. 각 단계는 테스트 인프라를 새로 만들고 삭제하므로 Redis 대기열과 DB 상태가 섞이지 않는다. 한 단계가 실패하면 다음 단계로 진행하지 않는다. 흐름 완료 시간 SLO는 기본으로 제외한다. 이때도 성공률, 선점 시간, 대기열 진입 시간, 완료 흐름 기준은 유지한다. 테스트 완료·실패·중단 후에도 `finally`에서 테스트 EC2와 RDS를 삭제한다. 자원을 남겨 재실행하려면 단일 `-QueueActiveLimit`과 함께 `-KeepInfrastructure`를 사용하며, 종료 후 수동 destroy가 필요하다.

```powershell
.\loadtest\Invoke-LoadTest.ps1 -UserLevels 50,100,200 -Duration 3m
.\loadtest\Invoke-LoadTest.ps1 -QueueActiveLimits 200,400,800
.\loadtest\Invoke-LoadTest.ps1 -QueueActiveLimit 400 -Duration 35m
.\loadtest\Invoke-LoadTest.ps1 -KeepInfrastructure
```

10,000명 수용성 검증은 6대 `c7i.xlarge`(총 24 vCPU)와 ALB, `db.t4g.medium`으로 구성된 격리 환경을 만들며 Redis는 `cache.t4g.micro`를 유지한다. C7i는 현재 x86 AMI·이미지와 호환된다. CMD에서는 사용자 수 목록을 하나의 인자로 전달한다.

```cmd
.\loadtest\Run-LoadTest.cmd -UserLevels "600,800,1000" -Duration 5m -IgnoreFlowSlo
```

10,000명 검증은 응답 시간 SLO를 모두 제외하고 다음처럼 실행한다. 로컬 부하 발생기의 CPU·메모리·네트워크가 먼저 포화되면 분산 k6 발생기로 전환한다.

```cmd
.\loadtest\Run-LoadTest.cmd -UserLevels "10000" -Duration 35m -IgnoreFlowSlo
```

현재 기본값도 위 명령과 동일하다. `Duration`은 반복 부하 유지 시간이 아니라 사용자별 1회 실행의 전체 종료 한도다. 로그인은 측정 전에 로컬 발생기가 최대 20개 동시 요청으로 완료하고, 토큰은 권한을 제한한 임시 파일로 k6에 공유한 뒤 종료 즉시 삭제한다. 그 뒤 10,000 VU는 최초 대기열 진입을 기본 10초에 균등 분산하고 최대 30분 기다린 후 선점·해제·퇴장을 수행한다. 이는 로컬 Windows의 DNS·TCP 연결 폭주를 피하면서도 1만 명의 대기열 유입을 검증하기 위한 조건이다. 대기열 상태 폴링 주기는 바꾸지 않는다. 모든 사용자가 끝나면 일찍 종료한다. 통과 조건은 HTTP 실패 0건, 흐름 성공률 100%, 완료 흐름 및 iteration 수가 요청한 사용자 수와 일치하는 것이다. 이는 사전 로그인된 고유 사용자 1만 명의 완료 검증이다. 스모크/소규모 사전 검사도 각각 사용자별 1회만 실행한다.

기본 실행은 테스트 동안 최초 ALB IPv4 DNS 응답을 유지한다. 이전 실행에서 5분 시점에 발생한 DNS 재해석 폭주를 막기 위한 조치다. 테스트 중 ALB를 교체·삭제하지 않는 격리 환경에서만 사용한다. 유입 분산을 조정하려면 다음처럼 실행하며, `0`은 정확히 동시에 연결하므로 로컬 PC 1대로 1만 명 검증할 때 권장하지 않는다.

```powershell
.\loadtest\Invoke-LoadTest.ps1 -QueueIngressSpreadSeconds 120
```

토큰은 VU별로 하나만 보관한다. 정상 예외/실패 경로에서는 선점 해제 및 대기열 퇴장을 시도하지만 프로세스 강제 종료 시 정리는 보장되지 않는다. 실패하면 다음 단계로 진행하지 않고 격리 인프라를 삭제한다. `-KeepInfrastructure` 사용 시 잔여 대기열을 가진 상태로 재실행하지 않는다.

DB 풀은 인스턴스당 최대 20개/최소 유휴 1개(6대 합계 최대 120개)이며 DB 연결 한도 140개 이상을 준비 단계에서 확인한다. 전체 SSM Online 및 ALB healthy를 확인한 뒤 진행한다. 실행 전에 On-Demand Standard vCPU의 실제 사용량과 24 vCPU 요청량을 조회해 계정 할당량을 넘으면 apply 전에 중단한다. 현재 할당량 48 vCPU에서 기존 사용량이 24 vCPU 이하이면 실행 가능하다. 부분 apply 실패 시에도 테스트 자원 정리를 시도한다.

`generator-resources.json`에는 5초 간격 발생기 호스트 CPU와 가용 메모리를 저장한다. CPU 포화 또는 메모리 부족 구간은 서버 한계로 단정하지 않는다. 네트워크 포화는 별도 확인해야 한다. HTTP 원본 집계는 스트리밍하지만 원본 파일은 계속 디스크를 사용하므로 충분한 저장 공간이 필요하다. DB 지표는 RDS identifier로 조회하며 앱 CPU는 6대별로 기록한다.

자동 생성되는 [infra/loadtest/terraform.tfvars](C:/Users/조영진/S15P21D206/infra/loadtest/terraform.tfvars)는 현재 공인 IP `/32`, 기존 VPC/서브넷, 운영 RDS 엔진·클래스, 앱 인스턴스 사양, 최신 ECR digest를 담는다. DB 비밀번호는 매번 임의 생성해 현재 PowerShell 프로세스에만 주입한다. 두 파일 모두 Git에 무시된다. 운영 RDS와 운영 앱에는 데이터를 쓰지 않는다.

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

한 번에 하나만 실행한다. 로그인은 각 실행 전에 저부하 사전 단계에서 수행되며, 토큰 파일은 k6 종료 직후 삭제된다. 실행 간 해제 실패가 있으면 최소 5분 기다리고 스모크를 다시 확인한다. 동일 조건 비교 실험은 DB를 새로 생성해 시작한다(선점 이력 등 데이터가 누적됨).
현재 시드 상한은 2,000명이다. 상한까지 통과하면 "2,000명 이상 수용 확인"으로 기록하며 최대라고 단정하지 않는다.

구간별 합격 기준은 성공률 >=99%, 흐름 p95 <=3초, 선점 p95 <=1.5초, 완료 흐름 >0이다. 실패·타임아웃도 흐름 성공률에 포함하고 실패 후에도 2초 쉰다. 구간마다 독립 k6 실행이므로 워밍업/다른 구간 평균이 섞이지 않는다. 종료 코드 2는 측정 기준 실패, 그 밖의 오류는 실행 문제다.

## 매번 문서화

`loadtest/results/<시간>-<인원>vu/`에 자동 저장된다.

- `report.md`: 조건·성공률·p95·flows/s·통과/실패 한 표. **병목과 최종 판단 두 줄만 직접 작성**한다.
- `summary.json`: 판정 지표 원본.
- `http-status.json`: API·HTTP 상태 코드별 요청 수. 실패 원인을 먼저 여기서 확인한다. `k6-raw.json`은 이 집계의 원본 요청 이벤트다. 로그인 토큰은 결과에 저장하지 않는다.
- `app-log-tail.txt`: k6 종료 직후 SSM으로 수집한 앱 컨테이너 최근 로그와 메모리 사용량. 5xx가 있으면 이 파일을 함께 확인한다.
- `config.json`: 이미지 digest, 인프라 식별자, 로컬 OS/CPU/메모리/k6 버전.
- `cloudwatch.json`: 앱 CPU, DB CPU/연결 수. CloudWatch 수집 지연 때문에 마지막 구간이 누락될 수 있다.

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
