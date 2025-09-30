#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}

echo "🚀 프론트엔드 수동 배포 시작..."
echo "Environment: $ENVIRONMENT"
echo "Image Tag: $IMAGE_TAG"

# Check if kustomize is installed
if ! command -v kustomize &> /dev/null; then
    echo "Installing Kustomize..."
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/
fi

# Load environment variables from .github/config
if [[ -f ".github/config/deploy_env_vars_${ENVIRONMENT}" ]]; then
    source ".github/config/deploy_env_vars_${ENVIRONMENT}"
    echo "✅ Environment variables loaded for $ENVIRONMENT"
else
    echo "❌ Environment configuration file not found: .github/config/deploy_env_vars_${ENVIRONMENT}"
    exit 1
fi

# Create namespace
echo "📝 Creating namespace phonebill-dg0500..."
kubectl create namespace phonebill-dg0500 --dry-run=client -o yaml | kubectl apply -f -

# 환경별 이미지 태그 업데이트 (.github/kustomize 사용)
cd .github/kustomize/overlays/${ENVIRONMENT}

echo "🔄 Updating image tags..."
# 이미지 태그 업데이트
kustomize edit set image acrdigitalgarage01.azurecr.io/phonebill/phonebill-front:${ENVIRONMENT}-${IMAGE_TAG}

echo "🚀 Deploying to Kubernetes..."
# 배포 실행
kubectl apply -k .

echo "⏳ Waiting for deployments to be ready..."
# 배포 상태 확인
kubectl rollout status deployment/phonebill-front -n phonebill-dg0500 --timeout=300s

echo "🔍 Health check..."
# Health Check
POD=$(kubectl get pod -n phonebill-dg0500 -l app.kubernetes.io/name=phonebill-front -o jsonpath='{.items[0].metadata.name}')
kubectl -n phonebill-dg0500 exec $POD -- curl -f http://localhost:8080/ || echo "Health check failed, but deployment completed"

echo "📋 Service Information:"
kubectl get pods -n phonebill-dg0500
kubectl get services -n phonebill-dg0500
kubectl get ingress -n phonebill-dg0500

echo "✅ GitHub Actions frontend deployment completed successfully!"