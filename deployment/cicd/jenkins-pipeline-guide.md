# phonebill-front Jenkins CI/CD 파이프라인 가이드

## 📋 목차
1. [개요](#개요)
2. [사전 준비](#사전-준비)
3. [Jenkins 환경 구성](#jenkins-환경-구성)
4. [Kustomize 구조](#kustomize-구조)
5. [Jenkins 파이프라인](#jenkins-파이프라인)
6. [배포 실행](#배포-실행)
7. [롤백 방법](#롤백-방법)
8. [트러블슈팅](#트러블슈팅)

---

## 개요

이 가이드는 **phonebill-front** 프론트엔드 서비스의 Jenkins + Kustomize 기반 CI/CD 파이프라인 구축 방법을 설명합니다.

### 시스템 정보
- **서비스명**: phonebill-front
- **시스템명**: phonebill
- **ACR**: acrdigitalgarage01
- **리소스 그룹**: rg-digitalgarage-01
- **AKS 클러스터**: aks-digitalgarage-01
- **네임스페이스**: phonebill-dg0500

### 주요 기능
- Node.js 기반 빌드 및 테스트
- SonarQube 코드 품질 분석
- Podman을 이용한 컨테이너 이미지 빌드
- Kustomize를 통한 환경별 매니페스트 관리
- AKS 자동 배포

---

## 사전 준비

### 1. 필수 소프트웨어
- Jenkins 2.x 이상
- kubectl CLI
- Azure CLI
- Docker Hub 계정 (Rate Limit 해결용)

### 2. 프로젝트 확인
```bash
# 서비스명 확인
cat package.json | grep '"name"'
# "name": "phonebill-front"
```

---

## Jenkins 환경 구성

### 1. 필수 플러그인 설치

Jenkins 관리 > Plugins > Available Plugins에서 다음 플러그인 설치:

```
- Kubernetes
- Pipeline Utility Steps
- Docker Pipeline
- GitHub
- SonarQube Scanner
- Azure Credentials
- EnvInject Plugin
```

### 2. Credentials 등록

#### Azure Service Principal
```
Manage Jenkins > Credentials > Add Credentials
- Kind: Microsoft Azure Service Principal
- ID: azure-credentials
- Subscription ID: {구독ID}
- Client ID: {클라이언트ID}
- Client Secret: {클라이언트시크릿}
- Tenant ID: {테넌트ID}
- Azure Environment: Azure
```

#### ACR Credentials
```
- Kind: Username with password
- ID: acr-credentials
- Username: acrdigitalgarage01
- Password: {ACR_PASSWORD}
```

#### Docker Hub Credentials (Rate Limit 해결용)
```
- Kind: Username with password
- ID: dockerhub-credentials
- Username: {DOCKERHUB_USERNAME}
- Password: {DOCKERHUB_PASSWORD}

참고: Docker Hub 무료 계정 생성 (https://hub.docker.com)
```

#### SonarQube Token
```
- Kind: Secret text
- ID: sonarqube-token
- Secret: {SonarQube토큰}
```

### 3. SonarQube 서버 설정

```
Manage Jenkins > System > SonarQube servers
- Name: SonarQube
- Server URL: {SonarQube서버URL}
- Server authentication token: sonarqube-token
```

---

## Kustomize 구조

### 디렉토리 구조
```
deployment/cicd/
├── Jenkinsfile                        # Jenkins 파이프라인 스크립트
├── config/
│   ├── deploy_env_vars_dev            # 개발 환경 설정
│   ├── deploy_env_vars_staging        # 스테이징 환경 설정
│   └── deploy_env_vars_prod           # 운영 환경 설정
├── kustomize/
│   ├── base/                          # 기본 매니페스트
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── ingress.yaml
│   └── overlays/                      # 환경별 오버레이
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
└── scripts/
    ├── deploy.sh                      # 수동 배포 스크립트
    └── validate-resources.sh          # 리소스 검증 스크립트
```

### Base 리소스 (deployment/cicd/kustomize/base/)

모든 환경에서 공통으로 사용되는 기본 매니페스트입니다. 네임스페이스는 하드코딩하지 않으며, Overlay에서 설정합니다.

**kustomization.yaml**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: phonebill-front-base

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - ingress.yaml

images:
  - name: acrdigitalgarage01.azurecr.io/phonebill/phonebill-front
    newTag: latest
```

### 환경별 Overlay

#### Dev 환경 (overlays/dev/)

**특징**:
- Replicas: 1
- Resources: 최소 (256m CPU, 256Mi Memory)
- HTTP 사용 (SSL Redirect: false)
- 기본 도메인 유지

**kustomization.yaml**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: phonebill-dg0500

resources:
  - ../../base

patches:
  - path: configmap-patch.yaml
    target:
      kind: ConfigMap
      name: cm-phonebill-front
  - path: deployment-patch.yaml
    target:
      kind: Deployment
      name: phonebill-front
  - path: ingress-patch.yaml
    target:
      kind: Ingress
      name: phonebill-front

images:
  - name: acrdigitalgarage01.azurecr.io/phonebill/phonebill-front
    newTag: latest
```

#### Staging 환경 (overlays/staging/)

**특징**:
- Replicas: 2
- Resources: 중간 (512m CPU, 512Mi Memory)
- HTTPS 강제 (SSL Redirect: true)
- 도메인: phonebill-front-staging.example.com

#### Prod 환경 (overlays/prod/)

**특징**:
- Replicas: 3
- Resources: 최대 (1024m CPU, 1024Mi Memory)
- HTTPS 강제 (SSL Redirect: true)
- 도메인: phonebill-front.example.com

### 환경별 설정 파일

**deployment/cicd/config/deploy_env_vars_{환경}**
```bash
# {환경} Environment Configuration
resource_group=rg-digitalgarage-01
cluster_name=aks-digitalgarage-01
```

---

## Jenkins 파이프라인

### Pipeline Job 생성

1. Jenkins 웹 UI에서 **New Item > Pipeline** 선택
2. **Pipeline script from SCM** 설정:
   ```
   SCM: Git
   Repository URL: {Git저장소URL}
   Branch: main (또는 develop)
   Script Path: deployment/cicd/Jenkinsfile
   ```

### Pipeline Parameters 설정

```
ENVIRONMENT: Choice Parameter
- Choices: dev, staging, prod
- Default: dev
- Description: 배포 환경 선택

IMAGE_TAG: String Parameter
- Default: latest
- Description: 컨테이너 이미지 태그 (선택사항)

SKIP_SONARQUBE: String Parameter
- Default: true
- Description: SonarQube 코드 분석 스킵 여부 (true/false)
```

### Jenkinsfile 주요 구성

파이프라인은 다음 스테이지로 구성됩니다:

1. **Get Source**: Git 소스 체크아웃 및 환경 설정 로드
2. **Setup AKS**: Azure 로그인 및 AKS 인증 설정
3. **Build & Test**: npm 빌드 및 ESLint 실행
4. **SonarQube Analysis & Quality Gate**: 코드 품질 분석 (선택적)
5. **Build & Push Images**: Podman 이미지 빌드 및 ACR 푸시
6. **Update Kustomize & Deploy**: Kustomize 이미지 태그 업데이트 및 배포

### Pod Template 설정

**주요 특징**:
- **자동 정리**: podRetention: never()로 파이프라인 완료 시 파드 즉시 삭제
- **빠른 종료**: terminationGracePeriodSeconds: 3으로 3초 내 강제 종료
- **유휴 시간**: idleMinutes: 1로 유휴 상태 1분 후 정리

**컨테이너**:
- node:slim - Node.js 빌드 및 테스트
- mgoltzsche/podman - 컨테이너 이미지 빌드
- hiondal/azure-kubectl:latest - AKS 배포
- sonarsource/sonar-scanner-cli:latest - SonarQube 분석

---

## 배포 실행

### 1. Jenkins UI를 통한 배포

```
1. Jenkins > {프로젝트명} > Build with Parameters
2. ENVIRONMENT 선택 (dev/staging/prod)
3. IMAGE_TAG 입력 (선택사항, 기본값: 타임스탬프)
4. SKIP_SONARQUBE 설정 (true/false)
5. Build 클릭
```

### 2. 수동 배포 (스크립트 사용)

```bash
# 개발환경 배포
./deployment/cicd/scripts/deploy.sh dev

# 스테이징환경 배포
./deployment/cicd/scripts/deploy.sh staging

# 운영환경 배포 (특정 태그)
./deployment/cicd/scripts/deploy.sh prod 20250930120000
```

### 3. 배포 상태 확인

```bash
# Pod 상태 확인
kubectl get pods -n phonebill-dg0500

# Service 확인
kubectl get services -n phonebill-dg0500

# Ingress 확인
kubectl get ingress -n phonebill-dg0500

# 배포 이력 확인
kubectl rollout history deployment/phonebill-front -n phonebill-dg0500

# 상세 상태 확인
kubectl describe deployment phonebill-front -n phonebill-dg0500
```

### 4. 로그 확인

```bash
# 실시간 로그 확인
kubectl logs -f deployment/phonebill-front -n phonebill-dg0500

# 최근 100줄 로그 확인
kubectl logs --tail=100 deployment/phonebill-front -n phonebill-dg0500

# 특정 Pod 로그 확인
kubectl logs {pod-name} -n phonebill-dg0500
```

---

## 롤백 방법

### 1. 이전 버전으로 롤백

```bash
# 롤백 가능한 리비전 확인
kubectl rollout history deployment/phonebill-front -n phonebill-dg0500

# 바로 이전 버전으로 롤백
kubectl rollout undo deployment/phonebill-front -n phonebill-dg0500

# 특정 리비전으로 롤백
kubectl rollout undo deployment/phonebill-front -n phonebill-dg0500 --to-revision=2

# 롤백 상태 확인
kubectl rollout status deployment/phonebill-front -n phonebill-dg0500
```

### 2. 이미지 태그 기반 롤백

특정 이미지 태그로 롤백하려면:

```bash
# 1. 이전 안정 버전 이미지 태그 확인
# 예: dev-20250930100000

# 2. 환경별 디렉토리로 이동
cd deployment/cicd/kustomize/overlays/dev

# 3. 이미지 태그 업데이트
kustomize edit set image acrdigitalgarage01.azurecr.io/phonebill/phonebill-front:dev-20250930100000

# 4. 배포 적용
kubectl apply -k .

# 5. 배포 상태 확인
kubectl rollout status deployment/phonebill-front -n phonebill-dg0500
```

---

## 트러블슈팅

### 1. 빌드 실패

#### npm 빌드 에러
```bash
# 증상: npm ci 또는 npm run build 실패

# 해결방법:
# 1. 로컬에서 빌드 테스트
npm ci
npm run build

# 2. package.json 의존성 확인
# 3. Node 버전 확인 (Jenkinsfile의 node:slim 이미지)
```

#### ESLint 에러
```bash
# 증상: npm run lint 실패

# 해결방법:
# 1. 로컬에서 lint 실행
npm run lint

# 2. .eslintrc.cjs 설정 확인
# 3. max-warnings 설정 확인 (현재: 20)
```

### 2. 이미지 빌드 실패

#### Docker Hub Rate Limit
```bash
# 증상: toomanyrequests: You have reached your pull rate limit

# 해결방법:
# 1. Docker Hub 계정 로그인 (Jenkinsfile에 이미 구현됨)
# 2. dockerhub-credentials 확인
```

#### ACR 로그인 실패
```bash
# 증상: unauthorized: authentication required

# 해결방법:
# 1. acr-credentials 확인
# 2. ACR 접근 권한 확인
az acr login --name acrdigitalgarage01
```

### 3. 배포 실패

#### Kustomize 빌드 실패
```bash
# 증상: kubectl apply -k . 실패

# 해결방법:
# 1. 리소스 검증 스크립트 실행
./deployment/cicd/scripts/validate-resources.sh

# 2. 수동으로 kustomize 빌드 테스트
kubectl kustomize deployment/cicd/kustomize/overlays/dev

# 3. 각 리소스 파일 문법 확인
```

#### Pod 시작 실패
```bash
# 증상: Pod가 Running 상태로 전환되지 않음

# 해결방법:
# 1. Pod 상태 확인
kubectl describe pod {pod-name} -n phonebill-dg0500

# 2. 이벤트 확인
kubectl get events -n phonebill-dg0500 --sort-by='.lastTimestamp'

# 3. 일반적인 원인:
# - ImagePullBackOff: 이미지 pull 실패
# - CrashLoopBackOff: 컨테이너 시작 실패
# - Pending: 리소스 부족
```

### 4. SonarQube 분석 실패

```bash
# 증상: SonarQube 분석 타임아웃 또는 실패

# 해결방법:
# 1. SKIP_SONARQUBE=true로 파이프라인 재실행
# 2. SonarQube 서버 상태 확인
# 3. sonarqube-token 확인

# 참고: 파이프라인은 SonarQube 실패 시에도 계속 진행됨
```

### 5. 네임스페이스 접근 오류

```bash
# 증상: namespace "phonebill-dg0500" not found

# 해결방법:
# 1. 네임스페이스 생성
kubectl create namespace phonebill-dg0500

# 2. 네임스페이스 확인
kubectl get namespace phonebill-dg0500
```

### 6. Jenkins Pod 정리 안됨

```bash
# 증상: 파이프라인 완료 후에도 Pod가 남아있음

# 해결방법:
# 1. Jenkinsfile의 podRetention 설정 확인
# podRetention: never()

# 2. 수동으로 Pod 정리
kubectl delete pod -l jenkins=slave -n jenkins

# 3. Jenkins Kubernetes Plugin 설정 확인
```

---

## 리소스 검증

### 검증 스크립트 실행

배포 전 리소스 누락 및 구성 오류를 확인합니다:

```bash
# 실행 권한 부여 (최초 1회)
chmod +x deployment/cicd/scripts/validate-resources.sh

# 검증 실행
./deployment/cicd/scripts/validate-resources.sh
```

### 검증 항목

1. **Base 디렉토리 파일 확인**
   - deployment.yaml
   - service.yaml
   - configmap.yaml
   - ingress.yaml

2. **kustomization.yaml 리소스 검증**
   - 모든 참조 파일 존재 확인

3. **Kustomize 빌드 테스트**
   - Base 및 환경별 Overlay 빌드 성공 여부

---

## 환경별 차이점 요약

| 항목 | Dev | Staging | Prod |
|------|-----|---------|------|
| Replicas | 1 | 2 | 3 |
| CPU Request | 256m | 512m | 1024m |
| Memory Request | 256Mi | 512Mi | 1024Mi |
| CPU Limit | 1024m | 2048m | 4096m |
| Memory Limit | 1024Mi | 2048Mi | 4096Mi |
| SSL Redirect | false | true | true |
| 도메인 | 기본 | staging | prod |
| NODE_ENV | development | staging | production |

---

## 참고 자료

### Kustomize 공식 문서
- https://kustomize.io/

### Jenkins Kubernetes Plugin
- https://plugins.jenkins.io/kubernetes/

### Azure CLI 참조
- https://learn.microsoft.com/en-us/cli/azure/

### 관련 파일
- `deployment/cicd/Jenkinsfile` - 파이프라인 스크립트
- `deployment/cicd/scripts/deploy.sh` - 수동 배포 스크립트
- `deployment/cicd/scripts/validate-resources.sh` - 리소스 검증 스크립트
- `.eslintrc.cjs` - ESLint 설정

---

## 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|-----------|
| 2025-09-30 | 1.0.0 | 초기 버전 작성 |

---

## 문의

기술 지원이 필요한 경우 DevOps 팀에 문의하세요.
