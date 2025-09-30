#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}

echo "🚀 Frontend 배포 시작 - 환경: $ENVIRONMENT, 태그: $IMAGE_TAG"

# 환경별 이미지 태그 업데이트
cd deployment/cicd/kustomize/overlays/${ENVIRONMENT}

# 이미지 태그 업데이트
kustomize edit set image acrdigitalgarage01.azurecr.io/phonebill/phonebill-front:${ENVIRONMENT}-${IMAGE_TAG}

# 배포 실행
kubectl apply -k .

# 배포 상태 확인
kubectl rollout status deployment/phonebill-front -n phonebill-dg0500 --timeout=300s

echo "✅ 배포 완료!"
