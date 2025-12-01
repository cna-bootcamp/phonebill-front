# 프론트엔드 컨테이너 실행 가이드

## 개요
phonebill-front 서비스를 로컬 환경에서 Docker 컨테이너로 실행하는 방법을 안내합니다.

## 실행 정보
| 항목 | 값 |
|------|-----|
| 시스템명 | phonebill |
| 서비스명 | phonebill-front |
| Image Registry | docker.io |
| 컨테이너 포트 | 8080 |
| 호스트 포트 | 3000 |

---

## 1. 사전 준비

### Docker 설치 확인
```bash
docker --version
```

### 프로젝트 디렉토리 이동
```bash
cd ~/home/workspace/phonebill-front
```

---

## 2. 컨테이너 이미지 생성

`deployment/container/build-image.md` 파일을 참조하여 이미지를 빌드합니다.

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

---

## 3. 컨테이너 레지스트리 로그인 (Docker Hub)

```bash
docker login docker.io -u {Docker Hub ID} -p {암호}
```

---

## 4. 컨테이너 이미지 태깅 및 푸시

### 이미지 태깅
```bash
docker tag phonebill-front:latest docker.io/phonebill/phonebill-front:latest
```

### 이미지 푸시
```bash
docker push docker.io/phonebill/phonebill-front:latest
```

---

## 5. 런타임 환경변수 파일 생성

로컬 실행을 위한 runtime-env.js 파일을 생성합니다.

### 디렉토리 생성
```bash
mkdir -p ~/phonebill-front/public
```

### runtime-env.js 파일 생성
```bash
cat > ~/phonebill-front/public/runtime-env.js << 'EOF'
// 런타임 환경 설정
window.__runtime_config__ = {
  // API 서버 설정
  USER_HOST: 'http://localhost:8080',
  BILL_HOST: 'http://localhost:8080',
  PRODUCT_HOST: 'http://localhost:8080',
  KOS_MOCK_HOST: 'http://localhost:8080',
  API_GROUP: '/api/v1',

  // 환경 설정
  NODE_ENV: 'development',

  // 기타 설정
  APP_NAME: '통신요금 관리 서비스',
  VERSION: '1.0.0'
};
EOF
```

> **참고**: 백엔드 서버 주소가 다른 경우 `USER_HOST`, `BILL_HOST`, `PRODUCT_HOST`, `KOS_MOCK_HOST` 값을 적절히 변경하세요.

---

## 6. 컨테이너 실행

```bash
SERVER_PORT=3000

docker run -d --name phonebill-front --rm -p ${SERVER_PORT}:8080 \
-v ~/phonebill-front/public/runtime-env.js:/usr/share/nginx/html/runtime-env.js \
phonebill-front:latest
```

### Docker Hub 이미지로 실행 시
```bash
SERVER_PORT=3000

docker run -d --name phonebill-front --rm -p ${SERVER_PORT}:8080 \
-v ~/phonebill-front/public/runtime-env.js:/usr/share/nginx/html/runtime-env.js \
docker.io/phonebill/phonebill-front:latest
```

---

## 7. 실행 확인

### 컨테이너 상태 확인
```bash
docker ps | grep phonebill-front
```

### 서비스 접속 테스트
```bash
curl http://localhost:3000/health
```

### 브라우저 접속
```
http://localhost:3000
```

---

## 8. 재배포 방법

### 8.1 소스 수정 후 Git 푸시 (로컬에서)
```bash
git add .
git commit -m "수정 내용"
git push
```

### 8.2 소스 내려받기
```bash
cd ~/home/workspace/phonebill-front
git pull
```

### 8.3 컨테이너 이미지 재생성
`deployment/container/build-image.md` 참조하여 이미지 빌드

### 8.4 컨테이너 이미지 푸시 (선택)
```bash
docker tag phonebill-front:latest docker.io/phonebill/phonebill-front:latest
docker push docker.io/phonebill/phonebill-front:latest
```

### 8.5 컨테이너 중지
```bash
docker stop phonebill-front
```

### 8.6 컨테이너 이미지 삭제 (선택)
```bash
docker rmi docker.io/phonebill/phonebill-front:latest
```

### 8.7 컨테이너 재실행
```bash
SERVER_PORT=3000

docker run -d --name phonebill-front --rm -p ${SERVER_PORT}:8080 \
-v ~/phonebill-front/public/runtime-env.js:/usr/share/nginx/html/runtime-env.js \
phonebill-front:latest
```

---

## 문제 해결

### 컨테이너 로그 확인
```bash
docker logs phonebill-front
```

### 컨테이너 강제 종료
```bash
docker stop phonebill-front
docker rm phonebill-front 2>/dev/null || true
```

### 포트 충돌 시
`SERVER_PORT` 값을 다른 포트(예: 3001, 8081)로 변경하여 실행
