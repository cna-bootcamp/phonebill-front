# phonebill-front 쿠버네티스 배포 가이드

## 1. 배포 정보

| 항목 | 값 |
|------|-----|
| 시스템명 | phonebill |
| 서비스명 | phonebill-front |
| Image Registry | docker.io |
| Image Organization | hiondal |
| 이미지명 | docker.io/hiondal/phonebill-front:latest |
| k8s context | minikube-remote |
| 네임스페이스 | phonebill |
| 파드수 | 1 |
| 리소스(CPU) | 256m / 1024m (요청/최대) |
| 리소스(메모리) | 256Mi / 1024Mi (요청/최대) |
| Gateway Host | http://phonebill-api.72.155.72.236.nip.io |
| Frontend Host | http://phonebill.72.155.72.236.nip.io |

## 2. 매니페스트 파일 목록

| 파일명 | 설명 | 객체명 |
|--------|------|--------|
| configmap.yaml | 런타임 환경 설정 | cm-phonebill-front |
| service.yaml | 서비스 정의 | phonebill-front |
| deployment.yaml | 디플로이먼트 정의 | phonebill-front |
| ingress.yaml | 인그레스 정의 | phonebill-front |

## 3. 체크리스트 검증 결과

### 3.1 객체 네이밍룰 준수 여부
| 객체 타입 | 네이밍룰 | 실제 이름 | 준수 |
|-----------|----------|-----------|------|
| Ingress | {서비스명} | phonebill-front | ✅ |
| ConfigMap | cm-{서비스명} | cm-phonebill-front | ✅ |
| Service | {서비스명} | phonebill-front | ✅ |
| Deployment | {서비스명} | phonebill-front | ✅ |

### 3.2 Ingress Controller External IP 확인
```bash
# 확인 명령어
kubectl get svc ingress-nginx-controller -n ingress-nginx
```
- **Gateway Host에서 추출한 External IP**: 72.155.72.236
- **Ingress Host 설정값**: phonebill.72.155.72.236.nip.io ✅

### 3.3 포트 설정 확인
| 항목 | 설정값 | 검증 |
|------|--------|------|
| Ingress backend.service.port.number | 8080 | ✅ |
| Service port | 8080 | ✅ |
| Service targetPort | 8080 | ✅ |

### 3.4 이미지명 형식 확인
- **형식**: docker.io/hiondal/phonebill-front:latest
- **검증**: ✅ '{Registry}/{Organization}/{서비스명}:latest' 형식 준수

### 3.5 ConfigMap 설정 확인
| 항목 | 설정값 | 검증 |
|------|--------|------|
| ConfigMap 이름 | cm-phonebill-front | ✅ |
| data key | runtime-env.js | ✅ |
| USER_HOST | http://phonebill-api.72.155.72.236.nip.io | ✅ |
| BILL_HOST | http://phonebill-api.72.155.72.236.nip.io | ✅ |
| PRODUCT_HOST | http://phonebill-api.72.155.72.236.nip.io | ✅ |
| KOS_MOCK_HOST | http://phonebill-api.72.155.72.236.nip.io | ✅ |

## 4. 사전 확인

### 4.1 Kubernetes Context 확인
```bash
# 현재 context 확인
kubectl config current-context

# minikube-remote context로 변경 (필요시)
kubectl config use-context minikube-remote

# 클러스터 연결 상태 확인
kubectl cluster-info
```

### 4.2 네임스페이스 확인
```bash
# 네임스페이스 존재 확인
kubectl get ns phonebill

# 네임스페이스가 없으면 생성
kubectl create ns phonebill
```

### 4.3 Ingress Controller 확인
```bash
# Ingress Controller External IP 확인
kubectl get svc ingress-nginx-controller -n ingress-nginx
```
출력 예시:
```
NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
ingress-nginx-controller   LoadBalancer   10.x.x.x       72.155.72.236    80:xxxxx/TCP,443:xxxxx/TCP
```

### 4.4 이미지 레지스트리 인증 (Docker Hub)
```bash
# Docker Hub 인증 정보로 시크릿 생성 (아직 없는 경우)
kubectl create secret docker-registry phonebill \
  --docker-server=docker.io \
  --docker-username=<DOCKER_USERNAME> \
  --docker-password=<DOCKER_PASSWORD> \
  --docker-email=<DOCKER_EMAIL> \
  -n phonebill

# 시크릿 존재 확인
kubectl get secret phonebill -n phonebill
```

## 5. 배포 실행

### 5.1 매니페스트 적용
```bash
# deployment/k8s 디렉토리의 모든 매니페스트 적용
kubectl apply -f deployment/k8s
```

### 5.2 배포 확인
```bash
# 모든 리소스 확인
kubectl get all -n phonebill

# ConfigMap 확인
kubectl get configmap cm-phonebill-front -n phonebill

# Ingress 확인
kubectl get ingress phonebill-front -n phonebill

# Pod 상태 상세 확인
kubectl get pods -n phonebill -l app=phonebill-front -w

# Pod 로그 확인 (문제 발생 시)
kubectl logs -f -l app=phonebill-front -n phonebill
```

### 5.3 객체 생성 확인 명령어
```bash
# Deployment 상태 확인
kubectl describe deployment phonebill-front -n phonebill

# Service 상태 확인
kubectl describe service phonebill-front -n phonebill

# Ingress 상태 확인
kubectl describe ingress phonebill-front -n phonebill

# ConfigMap 내용 확인
kubectl get configmap cm-phonebill-front -n phonebill -o yaml
```

## 6. 서비스 접속 확인

### 6.1 브라우저 접속
```
http://phonebill.72.155.72.236.nip.io
```

### 6.2 curl 테스트
```bash
# 프론트엔드 접속 확인
curl -I http://phonebill.72.155.72.236.nip.io

# Health 체크
curl http://phonebill.72.155.72.236.nip.io/health
```

## 7. 트러블슈팅

### 7.1 Pod가 시작되지 않는 경우
```bash
# Pod 상태 확인
kubectl describe pod -l app=phonebill-front -n phonebill

# 이벤트 확인
kubectl get events -n phonebill --sort-by='.lastTimestamp'
```

### 7.2 이미지 Pull 실패 시
```bash
# ImagePullSecret 확인
kubectl get secret phonebill -n phonebill

# Pod의 이미지 pull 에러 확인
kubectl describe pod -l app=phonebill-front -n phonebill | grep -A5 "Events"
```

### 7.3 Ingress 접속 불가 시
```bash
# Ingress Controller 상태 확인
kubectl get pods -n ingress-nginx

# Ingress 설정 확인
kubectl describe ingress phonebill-front -n phonebill
```

## 8. 리소스 삭제 (필요시)

```bash
# 전체 리소스 삭제
kubectl delete -f deployment/k8s

# 개별 리소스 삭제
kubectl delete deployment phonebill-front -n phonebill
kubectl delete service phonebill-front -n phonebill
kubectl delete ingress phonebill-front -n phonebill
kubectl delete configmap cm-phonebill-front -n phonebill
```

## 9. 재배포 방법

### 9.1 이미지 업데이트 후 재배포
```bash
# 이미지 재빌드 및 푸시 후
kubectl rollout restart deployment phonebill-front -n phonebill

# 롤아웃 상태 확인
kubectl rollout status deployment phonebill-front -n phonebill
```

### 9.2 ConfigMap 변경 후 재배포
```bash
# ConfigMap 업데이트
kubectl apply -f deployment/k8s/configmap.yaml

# Pod 재시작 (ConfigMap 변경 반영)
kubectl rollout restart deployment phonebill-front -n phonebill
```
