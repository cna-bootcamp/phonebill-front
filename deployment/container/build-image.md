# 프론트엔드 컨테이너 이미지 빌드 가이드

## 개요
phonebill-front 서비스의 컨테이너 이미지 빌드 방법을 설명합니다.

## 사전 준비
- Docker 설치 필요
- Node.js 20.x 이상 (로컬 테스트 시)

## 빌드 절차

### 1. 의존성 동기화
```bash
npm install
```

### 2. 컨테이너 이미지 빌드
```bash
DOCKER_FILE=deployment/container/Dockerfile-frontend

docker build \
  --platform linux/amd64 \
  --build-arg PROJECT_FOLDER="." \
  --build-arg BUILD_FOLDER="deployment/container" \
  --build-arg EXPORT_PORT="8080" \
  -f ${DOCKER_FILE} \
  -t phonebill-front:latest .
```

### 3. 빌드 결과 확인
```bash
docker images | grep phonebill-front
```

## 빌드 결과
| 항목 | 값 |
|------|-----|
| 이미지명 | phonebill-front:latest |
| 이미지 크기 | 약 21.5MB |
| 베이스 이미지 | nginx:stable-alpine |
| 노출 포트 | 8080 |

## 파일 구조
```
deployment/container/
├── Dockerfile-frontend    # 멀티스테이지 Dockerfile
├── nginx.conf             # Nginx 설정 파일
└── build-image.md         # 본 문서
```

## 참고사항
- 멀티스테이지 빌드 사용 (node:20-slim → nginx:stable-alpine)
- SPA 라우팅을 위한 try_files 설정 포함
- 정적 파일 캐싱 설정 포함 (1년)
- Health check 엔드포인트: `/health`
