# GitHub Actions CI/CD 파이프라인 가이드

## 목차
1. [개요](#개요)
2. [사전 준비사항](#사전-준비사항)
3. [파이프라인 구조](#파이프라인-구조)
4. [GitHub 저장소 설정](#github-저장소-설정)
5. [워크플로우 실행 방법](#워크플로우-실행-방법)
6. [수동 배포 방법](#수동-배포-방법)
7. [롤백 방법](#롤백-방법)
8. [SonarQube 설정](#sonarqube-설정)
9. [트러블슈팅](#트러블슈팅)

---

## 개요

본 가이드는 **phonebill-front** 프론트엔드 서비스를 GitHub Actions와 Kustomize를 이용하여 Azure Kubernetes Service(AKS)에 자동 배포하는 CI/CD 파이프라인 구축 방법을 안내합니다.

### 주요 특징
- **자동화된 빌드 및 테스트**: Node.js 기반 빌드, ESLint 검사
- **코드 품질 분석**: SonarQube 연동 (선택적)
- **컨테이너 이미지 빌드**: Docker 이미지 빌드 및 Azure Container Registry(ACR) 푸시
- **환경별 배포**: dev, staging, prod 환경별 자동 배포
- **Kustomize 기반 매니페스트 관리**: 환경별 설정 오버레이

---

## 사전 준비사항

### 1. 시스템 정보 확인

프로젝트의 실행 정보:
- **SYSTEM_NAME**: phonebill
- **SERVICE_NAME**: phonebill-front
- **ACR_NAME**: acrdigitalgarage01
- **RESOURCE_GROUP**: rg-digitalgarage-01
- **AKS_CLUSTER**: aks-digitalgarage-01
- **NAMESPACE**: phonebill-dg0500
- **NODE_VERSION**: 20

### 2. 필요한 도구
- Azure CLI
- kubectl
- kustomize
- Docker (로컬 테스트용)

### 3. Azure 리소스
- Azure Container Registry (ACR) 생성 완료
- Azure Kubernetes Service (AKS) 클러스터 생성 완료
- Azure Service Principal 생성 완료

---

## 파이프라인 구조

GitHub Actions 워크플로우는 3개의 주요 Job으로 구성됩니다:

### 1. Build Job
- 소스 코드 체크아웃
- Node.js 환경 설정
- 의존성 설치 (`npm ci`)
- 빌드 및 린트 실행 (`npm run build`, `npm run lint`)
- SonarQube 코드 분석 (선택적)
- 빌드 아티팩트 업로드

### 2. Release Job
- 빌드 아티팩트 다운로드
- Docker 이미지 빌드
- ACR에 이미지 푸시
- 이미지 태그: `{environment}-{timestamp}` 형식

### 3. Deploy Job
- Azure CLI 및 kubectl 설정
- AKS 클러스터 인증
- Namespace 생성
- Kustomize를 이용한 매니페스트 적용
- 배포 상태 확인

---

## GitHub 저장소 설정

### 1. GitHub Repository Secrets 설정

GitHub Repository > Settings > Secrets and variables > Actions > Repository secrets에 다음 시크릿을 등록합니다:

#### Azure Service Principal
```json
AZURE_CREDENTIALS:
{
  "clientId": "{클라이언트ID}",
  "clientSecret": "{클라이언트시크릿}",
  "subscriptionId": "{구독ID}",
  "tenantId": "{테넌트ID}"
}
```

**예시:**
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxx~xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

#### ACR Credentials
ACR 자격증명 확인 방법:
```bash
az acr credential show --name acrdigitalgarage01
```

등록할 시크릿:
```
ACR_USERNAME: acrdigitalgarage01
ACR_PASSWORD: {ACR패스워드}
```

#### Docker Hub Credentials (Rate Limit 방지)
Docker Hub에서 Personal Access Token 생성:
1. [Docker Hub](https://hub.docker.com)에 로그인
2. 우측 상단 프로필 아이콘 > Account Settings
3. 좌측 메뉴 'Personal Access Tokens' 클릭
4. 토큰 생성

등록할 시크릿:
```
DOCKERHUB_USERNAME: {Docker Hub 사용자명}
DOCKERHUB_PASSWORD: {Personal Access Token}
```

#### SonarQube 설정 (선택적)
SonarQube URL 확인:
```bash
kubectl get svc -n sonarqube
```

SonarQube 토큰 생성:
1. SonarQube 로그인
2. 우측 상단 'Administrator' > My Account
3. Security 탭에서 토큰 생성

등록할 시크릿:
```
SONAR_TOKEN: {SonarQube토큰}
SONAR_HOST_URL: http://{External IP}
```

### 2. GitHub Repository Variables 설정

GitHub Repository > Settings > Secrets and variables > Actions > Variables > Repository variables에 등록:

```
ENVIRONMENT: dev
SKIP_SONARQUBE: true
```

**변수 설명:**
- `ENVIRONMENT`: 기본 배포 환경 (dev/staging/prod)
- `SKIP_SONARQUBE`: SonarQube 분석 스킵 여부 (true/false)

---

## 워크플로우 실행 방법

### 1. 자동 실행 (Push/PR)

다음 경로의 파일이 변경되면 자동으로 워크플로우가 실행됩니다:
- `src/**`
- `public/**`
- `package*.json`
- `tsconfig*.json`
- `vite.config.ts`
- `index.html`
- `.github/**`

**실행 브랜치:**
- Push: `main`, `develop` 브랜치
- Pull Request: `main` 브랜치

**기본 설정:**
- Environment: dev
- Skip SonarQube: true

### 2. 수동 실행 (Workflow Dispatch)

GitHub 저장소에서:
1. Actions 탭 클릭
2. "Frontend CI/CD" 워크플로우 선택
3. "Run workflow" 버튼 클릭
4. 환경 선택:
   - **Environment**: dev / staging / prod
   - **Skip SonarQube Analysis**: true / false
5. "Run workflow" 버튼 클릭

---

## 수동 배포 방법

워크플로우를 거치지 않고 로컬에서 직접 배포할 수 있습니다.

### 사전 요구사항
- Azure CLI 로그인 완료
- AKS 클러스터 인증 완료
- kubectl 설정 완료

### 배포 실행

```bash
# 개발 환경 배포 (latest 태그)
./.github/scripts/deploy-actions-frontend.sh dev latest

# 개발 환경 배포 (특정 태그)
./.github/scripts/deploy-actions-frontend.sh dev 20240313120000

# 스테이징 환경 배포
./.github/scripts/deploy-actions-frontend.sh staging {image-tag}

# 운영 환경 배포
./.github/scripts/deploy-actions-frontend.sh prod {image-tag}
```

**스크립트 동작:**
1. 환경별 설정 파일 로드 (`.github/config/deploy_env_vars_{env}`)
2. Kustomize 설치 확인 및 설치
3. Namespace 생성
4. 이미지 태그 업데이트
5. Kubernetes 매니페스트 적용
6. 배포 상태 확인
7. Health Check

---

## 롤백 방법

### 1. GitHub Actions에서 이전 버전으로 롤백

1. GitHub > Actions 탭
2. 성공한 이전 워크플로우 실행 선택
3. "Re-run all jobs" 클릭

### 2. kubectl을 이용한 롤백

```bash
# 이전 버전으로 롤백
kubectl rollout undo deployment/phonebill-front -n phonebill-dg0500

# 특정 리비전으로 롤백
kubectl rollout undo deployment/phonebill-front -n phonebill-dg0500 --to-revision=2

# 롤백 히스토리 확인
kubectl rollout history deployment/phonebill-front -n phonebill-dg0500

# 롤백 상태 확인
kubectl rollout status deployment/phonebill-front -n phonebill-dg0500
```

### 3. 수동 스크립트를 이용한 롤백

이전에 성공한 이미지 태그를 사용하여 재배포:

```bash
# 이전 안정 버전으로 롤백
./.github/scripts/deploy-actions-frontend.sh dev 20240313100000
```

---

## SonarQube 설정

### 프로젝트 생성

1. SonarQube 웹 UI 접속
2. Projects > Create Project
3. 프로젝트 키: `phonebill-front-{환경}` (예: phonebill-front-dev)
4. 프로젝트 이름: `phonebill-front-{환경}`

### Quality Gate 설정

SonarQube에서 다음 품질 기준 설정:

| 메트릭 | 조건 | 값 |
|--------|------|-----|
| Coverage | >= | 70% |
| Duplicated Lines | <= | 3% |
| Maintainability Rating | <= | A |
| Reliability Rating | <= | A |
| Security Rating | <= | A |
| Code Smells | <= | 50 |
| Bugs | = | 0 |
| Vulnerabilities | = | 0 |

### 분석 실행 제어

**워크플로우에서 SonarQube 건너뛰기:**
- 자동 실행 시: Repository Variables의 `SKIP_SONARQUBE=true` 설정
- 수동 실행 시: "Skip SonarQube Analysis" 옵션을 `true`로 선택

**SonarQube 분석 활성화:**
- 수동 실행 시: "Skip SonarQube Analysis" 옵션을 `false`로 선택

---

## 트러블슈팅

### 1. 이미지 푸시 실패

**증상:** ACR에 이미지 푸시 중 인증 오류

**해결방법:**
```bash
# ACR 자격증명 확인
az acr credential show --name acrdigitalgarage01

# GitHub Secrets 업데이트
# ACR_USERNAME, ACR_PASSWORD 확인
```

### 2. Kustomize 빌드 실패

**증상:** `Error: unable to find one or more resources`

**해결방법:**
```bash
# 로컬에서 Kustomize 빌드 테스트
kubectl kustomize .github/kustomize/overlays/dev/

# base 디렉토리 파일 확인
ls .github/kustomize/base/

# 누락된 리소스 파일 확인 및 추가
```

### 3. Deployment 배포 실패

**증상:** Deployment가 Available 상태가 되지 않음

**해결방법:**
```bash
# Pod 상태 확인
kubectl get pods -n phonebill-dg0500

# Pod 로그 확인
kubectl logs -n phonebill-dg0500 -l app.kubernetes.io/name=phonebill-front

# Deployment 상태 확인
kubectl describe deployment phonebill-front -n phonebill-dg0500

# ConfigMap 확인
kubectl get configmap -n phonebill-dg0500
kubectl describe configmap cm-phonebill-front -n phonebill-dg0500
```

### 4. Docker Hub Rate Limit 오류

**증상:** `toomanyrequests: You have reached your pull rate limit`

**해결방법:**
- Docker Hub 자격증명이 GitHub Secrets에 올바르게 등록되었는지 확인
- `DOCKERHUB_USERNAME`, `DOCKERHUB_PASSWORD` 시크릿 확인

### 5. SonarQube 연결 실패

**증상:** SonarQube 분석 중 연결 오류

**해결방법:**
```bash
# SonarQube 서비스 상태 확인
kubectl get svc -n sonarqube

# SonarQube URL 접근 테스트
curl -I http://{SONAR_HOST_URL}

# GitHub Secrets에서 SONAR_HOST_URL, SONAR_TOKEN 확인
```

### 6. Namespace 권한 오류

**증상:** `Error from server (Forbidden): namespaces is forbidden`

**해결방법:**
- Azure Service Principal의 AKS 권한 확인
- Kubernetes RBAC 설정 확인
- Service Principal이 AKS 클러스터의 적절한 Role을 가지고 있는지 확인

---

## 디렉토리 구조

```
.github/
├── workflows/
│   └── frontend-cicd.yaml        # GitHub Actions 워크플로우
├── kustomize/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── ingress.yaml
│   └── overlays/
│       ├── dev/
│       │   ├── kustomization.yaml
│       │   ├── configmap-patch.yaml
│       │   ├── deployment-patch.yaml
│       │   └── ingress-patch.yaml
│       ├── staging/
│       │   ├── kustomization.yaml
│       │   ├── configmap-patch.yaml
│       │   ├── deployment-patch.yaml
│       │   └── ingress-patch.yaml
│       └── prod/
│           ├── kustomization.yaml
│           ├── configmap-patch.yaml
│           ├── deployment-patch.yaml
│           └── ingress-patch.yaml
├── config/
│   ├── deploy_env_vars_dev
│   ├── deploy_env_vars_staging
│   └── deploy_env_vars_prod
├── scripts/
│   └── deploy-actions-frontend.sh
└── actions-pipeline-guide.md     # 이 가이드 문서
```

---

## 체크리스트

### 사전 준비
- [ ] package.json에서 시스템명과 서비스명 확인
- [ ] Azure Service Principal 생성 및 자격증명 확보
- [ ] ACR 자격증명 확보
- [ ] AKS 클러스터 접근 권한 확인

### GitHub 설정
- [ ] AZURE_CREDENTIALS 시크릿 등록
- [ ] ACR_USERNAME, ACR_PASSWORD 시크릿 등록
- [ ] DOCKERHUB_USERNAME, DOCKERHUB_PASSWORD 시크릿 등록
- [ ] SONAR_TOKEN, SONAR_HOST_URL 시크릿 등록 (선택)
- [ ] ENVIRONMENT, SKIP_SONARQUBE 변수 등록

### 파이프라인 파일
- [ ] `.github/workflows/frontend-cicd.yaml` 생성 및 확인
- [ ] `.github/kustomize/base/` 디렉토리 및 매니페스트 생성
- [ ] `.github/kustomize/overlays/{dev,staging,prod}/` 생성
- [ ] 환경별 patch 파일 생성 및 확인
- [ ] `.github/config/deploy_env_vars_{env}` 파일 생성
- [ ] `.github/scripts/deploy-actions-frontend.sh` 생성 및 실행 권한 부여

### 검증
- [ ] 로컬에서 Kustomize 빌드 테스트 (`kubectl kustomize`)
- [ ] GitHub Actions 워크플로우 수동 실행 테스트
- [ ] 개발 환경 배포 성공 확인
- [ ] 배포된 서비스 접근 테스트

---

## 참고 자료

- [GitHub Actions 공식 문서](https://docs.github.com/en/actions)
- [Kustomize 공식 문서](https://kustomize.io/)
- [Azure Kubernetes Service 문서](https://docs.microsoft.com/en-us/azure/aks/)
- [SonarQube 문서](https://docs.sonarqube.org/)

---

## 문의

파이프라인 구축 및 운영 관련 문의사항은 DevOps 팀에 연락하시기 바랍니다.