# Terraform 인프라

## 구성

| 경로 | 역할 | 원격 상태 키 |
|---|---|---|
| `infra/` | 백엔드, 네트워크, DB, 이미지 저장소, API HTTPS | `app/prod/terraform.tfstate` |
| `infra/dns/` | 도메인 호스팅 영역 | `dns/terraform.tfstate` |
| `infra/ci/` | GitLab CI 실행 기반 | `ci/prod/terraform.tfstate` |

각 디렉터리는 독립적으로 실행합니다. 상태 키의 `prod`는 기존 경로이므로 현재 리소스의 `dev` 이름에 맞춰 임의 변경하지 않습니다.

`main.tf`는 모듈 연결, `variables.tf`는 입력, `outputs.tf`는 외부 출력을 담당합니다.

- `modules/image-storage`: 공개·개인 S3, CloudFront, 업로드 IAM 사용자와 키.
- `modules/api-domain`: API 인증서, DNS 검증, ALB 별칭 레코드.
- `modules/secrets-manager`: 백엔드 실행 환경 시크릿.
- 나머지 모듈: 네트워크·보안 그룹·EC2·NAT·RDS·ALB·ECR·백엔드 CI/CD.

## 환경변수

직접 입력하는 DB·JWT·SMS 설정은 Git에서 제외한 `terraform.tfvars`에 둡니다.
이미지 키·버킷·CDN 주소는 `module.image_storage.runtime_environment`에서 생성하고
`main.tf`가 기존 설정과 합쳐 Secrets Manager에 저장합니다. tfvars에 이미지 값을 복사하지 않습니다.

시크릿 변경은 다음 백엔드 배포 시 컨테이너에 반영됩니다.
이미지 저장과 JSON 응답 규칙은 [이미지 가이드](docs/images.md)를 참고하세요.

## 실행 (저장소 루트의 PowerShell)

```powershell
$env:AWS_PROFILE = 'ticketing-dev'
terraform '-chdir=infra' init
terraform '-chdir=infra' fmt -check -recursive
terraform '-chdir=infra' validate
terraform '-chdir=infra' plan '-out=changes.tfplan'
terraform '-chdir=infra' apply 'changes.tfplan'
```

`moved.tf`는 기존 리소스 주소를 새 모듈 주소로 이전합니다. 기존 환경의 업그레이드를
위해 유지하며, 모듈 정리만으로 버킷·키·인증서가 재생성되어서는 안 됩니다.

## CloudWatch 운영 지표

`terraform apply` 후 CloudWatch의 `${project_name}-${environment}-operations` 대시보드에서
애플리케이션 EC2와 RDS 지표를 함께 확인할 수 있습니다. EC2는 CloudWatch Agent가 60초마다
CPU·메모리·루트 디스크·스왑·네트워크 지표를 `Timo/EC2` 네임스페이스로 전송하고, RDS는
기본 `AWS/RDS` 지표(CPU·연결 수·여유 저장공간·지연·IOPS)를 사용합니다.

EC2 기본 지표도 60초 단위로 받도록 상세 모니터링을 기본 활성화했습니다. 비용을 피해야
하면 `terraform.tfvars`에 `ec2_detailed_monitoring = false`를 설정하세요. CloudWatch Agent의
사용자 정의 메트릭 및 상세 모니터링에는 AWS 과금이 적용될 수 있습니다.

Prometheus는 향후 별도 프라이빗 인스턴스에 `prometheus_security_group_id` 보안 그룹을 붙여
애플리케이션 EC2의 `:8080/actuator/prometheus`를 직접 수집합니다. 이 endpoint는 Spring에서
수집기 인증 없이 열지만, EC2 보안 그룹은 Prometheus 보안 그룹만 허용하고 ALB는 같은 경로를
404로 차단하므로 인터넷에서는 접근할 수 없습니다.

## Prometheus·Grafana 모니터링 인스턴스

Terraform은 프라이빗 앱 서브넷에 모니터링 EC2 한 대를 만들고, 부팅 및 SSM 재적용 시
Prometheus와 Grafana 컨테이너를 자동으로 실행합니다. Prometheus는 백엔드 EC2의 사설 IP를
15초마다 수집하고, Grafana에는 Prometheus 데이터 소스가 미리 등록됩니다. 두 웹 UI는
`127.0.0.1`에만 바인딩되므로 SSM 포트 포워딩으로 접근합니다.

적용 전, Git에서 제외된 `terraform.tfvars`에 16자 이상 Grafana 관리자 비밀번호를 추가해야 합니다.

```hcl
grafana_admin_password = "replace-with-a-long-unique-password"
```

Prometheus 데이터는 30GiB 암호화 gp3 루트 볼륨에 15일간 보존됩니다. 용량 또는 인스턴스
크기는 `monitoring_root_volume_size`, `monitoring_instance_type`으로 조절할 수 있습니다.

Grafana는 `https://grafana.<domain>`으로 공개됩니다. ALB만 Grafana 컨테이너의 3000 포트에
접근할 수 있고, Prometheus의 9090 포트 및 모니터링 EC2의 직접 접근은 계속 비공개입니다.
Grafana에서는 `admin`과 `grafana_admin_password`로 로그인하며, 익명 접근과 회원가입은 꺼져 있습니다.

`.terraform.lock.hcl`은 버전 재현성을 위해 커밋합니다. `*.tfvars`, 상태 파일,
계획 파일, `.terraform/`, `private/`의 비밀 전달 파일은 커밋하지 않습니다.
새 작업자의 AWS 인증은 본인 로컬 프로필을 사용하면 됩니다.
