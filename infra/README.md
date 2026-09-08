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

`.terraform.lock.hcl`은 버전 재현성을 위해 커밋합니다. `*.tfvars`, 상태 파일,
계획 파일, `.terraform/`, `private/`의 비밀 전달 파일은 커밋하지 않습니다.
새 작업자의 AWS 인증은 본인 로컬 프로필을 사용하면 됩니다.
