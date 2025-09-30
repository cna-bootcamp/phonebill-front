#!/bin/bash
# Frontend 리소스 누락 검증 스크립트

echo "🔍 phonebill-front Base 리소스 누락 검증 시작..."

BASE_DIR="deployment/cicd/kustomize/base"
MISSING_RESOURCES=0
REQUIRED_FILES=("deployment.yaml" "service.yaml" "configmap.yaml" "ingress.yaml")

# 1. base 디렉토리의 파일 확인
echo "1. Base 디렉토리 파일 목록:"
if [ -d "$BASE_DIR" ]; then
    for required in "${REQUIRED_FILES[@]}"; do
        if [ -f "$BASE_DIR/$required" ]; then
            echo "  ✅ $required"
        else
            echo "  ❌ MISSING REQUIRED: $required"
            ((MISSING_RESOURCES++))
        fi
    done
else
    echo "  ❌ Base 디렉토리가 없습니다"
    ((MISSING_RESOURCES++))
fi

# 2. kustomization.yaml과 실제 파일 비교
echo ""
echo "2. kustomization.yaml 리소스 검증:"
if [ -f "$BASE_DIR/kustomization.yaml" ]; then
    while IFS= read -r line; do
        # resources 섹션의 YAML 파일 경로 추출
        if [[ $line =~ ^[[:space:]]*-[[:space:]]*([^#]+\.yaml)[[:space:]]*$ ]]; then
            resource_path=$(echo "${BASH_REMATCH[1]}" | xargs)  # 공백 제거
            full_path="$BASE_DIR/$resource_path"
            if [ -f "$full_path" ]; then
                echo "  ✅ $resource_path"
            else
                echo "  ❌ MISSING: $resource_path"
                ((MISSING_RESOURCES++))
            fi
        fi
    done < "$BASE_DIR/kustomization.yaml"
else
    echo "  ❌ kustomization.yaml 파일이 없습니다"
    ((MISSING_RESOURCES++))
fi

# 3. kubectl kustomize 검증
echo ""
echo "3. Kustomize 빌드 테스트:"
if kubectl kustomize "$BASE_DIR" > /dev/null 2>&1; then
    echo "  ✅ Base kustomization 빌드 성공"
else
    echo "  ❌ Base kustomization 빌드 실패:"
    kubectl kustomize "$BASE_DIR" 2>&1 | head -5 | sed 's/^/     /'
    ((MISSING_RESOURCES++))
fi

# 4. 환경별 overlay 검증
echo ""
echo "4. 환경별 Overlay 검증:"
for env in dev staging prod; do
    overlay_dir="deployment/cicd/kustomize/overlays/$env"
    if [ -d "$overlay_dir" ] && [ -f "$overlay_dir/kustomization.yaml" ]; then
        if kubectl kustomize "$overlay_dir" > /dev/null 2>&1; then
            echo "  ✅ $env 환경 빌드 성공"
        else
            echo "  ❌ $env 환경 빌드 실패"
            ((MISSING_RESOURCES++))
        fi
    else
        echo "  ⚠️  $env 환경 설정 없음 (선택사항)"
    fi
done

# 결과 출력
echo ""
echo "======================================"
if [ $MISSING_RESOURCES -eq 0 ]; then
    echo "🎯 검증 완료! 모든 리소스가 정상입니다."
    echo "======================================"
    exit 0
else
    echo "❌ $MISSING_RESOURCES개의 문제가 발견되었습니다."
    echo "======================================"
    echo ""
    echo "💡 문제 해결 가이드:"
    echo "1. 누락된 파일들을 base 디렉토리에 추가하세요"
    echo "2. kustomization.yaml에서 존재하지 않는 파일 참조를 제거하세요"
    echo "3. 다시 검증: ./scripts/validate-resources.sh"
    exit 1
fi
