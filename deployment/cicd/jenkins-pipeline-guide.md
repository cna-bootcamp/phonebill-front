# phonebill-front Jenkins CI/CD 파이프라인 가이드

## 1. 개요

이 가이드는 Jenkins + Kustomize 기반 CI/CD 파이프라인을 구축하고 운영하는 방법을 설명합니다.

### 1.1 파이프라인 구성
- **빌드 환경**: Node.js 기반 React/Vite 프로젝트
- **컨테이너 빌드**: Podman
- **배포 관리**: Kustomize (환경별 Overlay)
- **코드 품질**: SonarQube (선택적)
- **대상 환경**: dev, staging, prod

### 1.2 주요 파일 구조
```
deployment/cicd/
├── Jenkinsfile                    # Jenkins 파이프라인 스크립트
├── jenkins-pipeline-guide.md      # 이 가이드 문서
├── config/
│   ├── deploy_env_vars_dev        # 개발환경 설정
│   ├── deploy_env_vars_staging    # 스테이징환경 설정
│   └── deploy_env_vars_prod       # 운영환경 설정
├── kustomize/
│   ├── base/                      # 기본 매니페스트
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── ingress.yaml
│   └── overlays/
│       ├── dev/                   # 개발환경 오버레이
│       ├── staging/               # 스테이징환경 오버레이
│       └── prod/                  # 운영환경 오버레이
└── scripts/
    ├── deploy.sh                  # 수동 배포 스크립트
    └── validate-resources.sh      # 리소스 검증 스크립트
```

---

## 2. Jenkins 서버 환경 구성

### 2.1 필수 플러그인
Jenkins에 다음 플러그인을 설치합니다:
```
- Kubernetes
- Pipeline Utility Steps
- Docker Pipeline
- GitHub
- SonarQube Scanner
- Azure Credentials
- EnvInject Plugin
```

### 2.2 Credentials 등록

Jenkins 관리 → Credentials → Add Credentials에서 다음 Credentials를 등록합니다:

#### Azure Service Principal
```
- Kind: Microsoft Azure Service Principal
- ID: azure-credentials
- Subscription ID: {구독ID}
- Client ID: {클라이언트ID}
- Client Secret: {클라이언트시크릿}
- Tenant ID: {테넌트ID}
- Azure Environment: Azure
```

#### Image Registry Credentials
```
- Kind: Username with password
- ID: imagereg-credentials
- Username: {Docker Hub 사용자명}
- Password: {Docker Hub 비밀번호}
```

#### Docker Hub Credentials (Rate Limit 해결용)
```
- Kind: Username with password
- ID: dockerhub-credentials
- Username: {DOCKERHUB_USERNAME}
- Password: {DOCKERHUB_PASSWORD}
참고: Docker Hub 무료 계정 생성 (https://hub.docker.com)
```

#### SonarQube Token (선택사항)
```
- Kind: Secret text
- ID: sonarqube-token
- Secret: {SonarQube토큰}
```

---

## 3. Jenkins Pipeline Job 생성

### 3.1 Pipeline Job 설정
1. Jenkins 웹 UI에서 **New Item > Pipeline** 선택
2. **Pipeline script from SCM** 설정:
   ```
   SCM: Git
   Repository URL: {Git저장소URL}
   Branch: main (또는 develop)
   Script Path: deployment/cicd/Jenkinsfile
   ```

### 3.2 Pipeline Parameters 설정
Jenkins Job의 "This project is parameterized"를 체크하고 다음 파라미터를 추가합니다:

| 파라미터명 | 타입 | 기본값 | 설명 |
|-----------|------|-------|------|
| ENVIRONMENT | Choice | dev | 배포 환경 선택 (dev, staging, prod) |
| IMAGE_TAG | String | latest | 컨테이너 이미지 태그 (선택사항) |
| SKIP_SONARQUBE | String | true | SonarQube 코드 분석 스킵 여부 (true/false) |

---

## 4. 파이프라인 단계별 설명

### 4.1 Get Source
- Git 저장소에서 소스코드 체크아웃
- 환경별 설정 파일 로드

### 4.2 Setup AKS
- 네임스페이스 생성 (없는 경우)
- Azure Kubernetes Service 연결

### 4.3 Build & Test
- `npm ci`: 의존성 설치
- `npm run build`: TypeScript 컴파일 및 Vite 빌드
- `npm run lint`: ESLint 코드 검사

### 4.4 SonarQube Analysis & Quality Gate (선택적)
- 코드 품질 분석 수행
- Quality Gate 결과 확인
- SKIP_SONARQUBE=true일 경우 스킵

### 4.5 Build & Push Images
- Podman으로 컨테이너 이미지 빌드
- 환경별 태그로 이미지 푸시 (예: dev-20241201120000)

### 4.6 Update Kustomize & Deploy
- Kustomize로 이미지 태그 업데이트
- Kubernetes 클러스터에 배포
- 배포 완료 대기 (최대 5분)

---

## 5. SonarQube 설정 (선택사항)

### 5.1 프로젝트 생성
SonarQube에서 프론트엔드 프로젝트를 생성합니다:
- 프로젝트 키: `phonebill-front-{환경}`
- 언어: JavaScript/TypeScript

### 5.2 Quality Gate 설정
```
Coverage: >= 70%
Duplicated Lines: <= 3%
Maintainability Rating: <= A
Reliability Rating: <= A
Security Rating: <= A
Code Smells: <= 50
Bugs: = 0
Vulnerabilities: = 0
```

---

## 6. 배포 실행 방법

### 6.1 Jenkins 파이프라인 실행
```
1. Jenkins > phonebill-front > Build with Parameters
2. ENVIRONMENT 선택 (dev/staging/prod)
3. IMAGE_TAG 입력 (선택사항)
4. SKIP_SONARQUBE 설정 (true/false)
5. Build 클릭
```

### 6.2 배포 상태 확인
```bash
# Pod 상태 확인
kubectl get pods -n phonebill

# Service 확인
kubectl get services -n phonebill

# Ingress 확인
kubectl get ingress -n phonebill

# 배포 상태 확인
kubectl rollout status deployment/phonebill-front -n phonebill
```

---

## 7. 수동 배포

### 7.1 수동 배포 실행
```bash
# 개발환경 배포
./deployment/cicd/scripts/deploy.sh dev

# 스테이징환경 배포
./deployment/cicd/scripts/deploy.sh staging

# 운영환경 배포 (특정 태그)
./deployment/cicd/scripts/deploy.sh prod 20241201120000
```

### 7.2 리소스 검증
```bash
# Kustomize 리소스 검증
./deployment/cicd/scripts/validate-resources.sh
```

---

## 8. 롤백 방법

### 8.1 이전 버전으로 롤백
```bash
# 배포 이력 확인
kubectl rollout history deployment/phonebill-front -n phonebill

# 특정 버전으로 롤백
kubectl rollout undo deployment/phonebill-front -n phonebill --to-revision=2

# 롤백 상태 확인
kubectl rollout status deployment/phonebill-front -n phonebill
```

### 8.2 이미지 태그 기반 롤백
```bash
# 이전 안정 버전 이미지 태그로 업데이트
cd deployment/cicd/kustomize/overlays/{환경}
kustomize edit set image docker.io/hiondal/phonebill-front:{환경}-{이전태그}
kubectl apply -k .
```

---

## 9. 환경별 설정

### 9.1 개발환경 (dev)
| 항목 | 값 |
|-----|-----|
| Replicas | 1 |
| CPU Requests | 256m |
| Memory Requests | 256Mi |
| CPU Limits | 1024m |
| Memory Limits | 1024Mi |
| SSL Redirect | false |

### 9.2 스테이징환경 (staging)
| 항목 | 값 |
|-----|-----|
| Replicas | 2 |
| CPU Requests | 512m |
| Memory Requests | 512Mi |
| CPU Limits | 2048m |
| Memory Limits | 2048Mi |
| SSL Redirect | true |

### 9.3 운영환경 (prod)
| 항목 | 값 |
|-----|-----|
| Replicas | 3 |
| CPU Requests | 1024m |
| Memory Requests | 1024Mi |
| CPU Limits | 4096m |
| Memory Limits | 4096Mi |
| SSL Redirect | true |

---

## 10. 트러블슈팅

### 10.1 빌드 실패
```bash
# 로컬에서 빌드 테스트
npm ci
npm run build
npm run lint
```

### 10.2 이미지 푸시 실패
- Docker Hub 인증 정보 확인
- Rate Limit 확인 (dockerhub-credentials 사용)

### 10.3 배포 실패
```bash
# Pod 로그 확인
kubectl logs -n phonebill deployment/phonebill-front

# Pod 상세 정보 확인
kubectl describe pod -n phonebill -l app=phonebill-front

# Events 확인
kubectl get events -n phonebill --sort-by='.lastTimestamp'
```

### 10.4 Kustomize 오류
```bash
# Kustomize 빌드 테스트
kubectl kustomize deployment/cicd/kustomize/base/
kubectl kustomize deployment/cicd/kustomize/overlays/dev/
```

---

## 11. 체크리스트

### 11.1 사전 준비
- [ ] Jenkins 플러그인 설치 완료
- [ ] Jenkins Credentials 등록 완료
- [ ] Kubernetes 클러스터 접근 확인
- [ ] Docker Hub 계정 생성 및 인증 정보 등록

### 11.2 파이프라인 설정
- [ ] Pipeline Job 생성 완료
- [ ] Parameters 설정 완료
- [ ] Git Repository 연결 완료

### 11.3 배포 전 검증
- [ ] 로컬 빌드 테스트 완료
- [ ] Kustomize 리소스 검증 완료
- [ ] 환경별 설정 파일 확인 완료

---

## 12. 참고 자료

- [Kustomize 공식 문서](https://kustomize.io/)
- [Jenkins Pipeline 문법](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Podman 문서](https://podman.io/)
- [SonarQube 문서](https://docs.sonarqube.org/)
