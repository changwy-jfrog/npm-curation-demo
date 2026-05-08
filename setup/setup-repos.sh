#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 기본값 로드
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"

usage() {
  echo "Usage: $0 [--project <project-key>]"
  echo ""
  echo "  --project <key>   JFrog 프로젝트 키 (생략 시 All Projects에 생성)"
  echo ""
  echo "Example:"
  echo "  $0                          # All Projects"
  echo "  $0 --project myteam         # 특정 프로젝트에 생성"
  exit 1
}

# 인자 파싱 (config.sh 값 오버라이드 가능)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT_KEY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "ERROR: 알 수 없는 옵션: $1"
      usage
      ;;
  esac
done

echo "=== JFrog Curation Demo: 레포지토리 설정 ==="
echo "서버: $SERVER_ID"
if [[ -n "$PROJECT_KEY" ]]; then
  echo "프로젝트: $PROJECT_KEY"
else
  echo "프로젝트: All Projects (미지정)"
fi
echo ""

# JFrog CLI 서버 등록 확인
if ! jf config show "$SERVER_ID" > /dev/null 2>&1; then
  echo "ERROR: JFrog CLI 서버 '$SERVER_ID' 가 설정되지 않았습니다."
  echo "다음 명령으로 먼저 설정하세요:"
  echo "  jf config add $SERVER_ID --url=https://solenglatest.jfrog.io --user=<USER> --password=<TOKEN>"
  exit 1
fi

# PROJECT_KEY가 있으면 JSON에 projectKey 필드를 주입한 임시 파일 반환
prepare_config() {
  local config="$1"
  if [[ -n "$PROJECT_KEY" ]]; then
    local tmp
    tmp=$(mktemp /tmp/jfrog-repo-XXXXXX.json)
    jq --arg pk "$PROJECT_KEY" '. + {projectKey: $pk}' "$config" > "$tmp"
    echo "$tmp"
  else
    echo "$config"
  fi
}

create_or_update_repo() {
  local config="$1"
  local repo_key
  repo_key=$(jq -r '.key' "$config")
  local prepared
  prepared=$(prepare_config "$config")

  if jf rt repo-show "$repo_key" --server-id="$SERVER_ID" > /dev/null 2>&1; then
    echo "  [UPDATE] $repo_key"
    jf rt repo-update "$prepared" --server-id="$SERVER_ID"
  else
    echo "  [CREATE] $repo_key"
    jf rt repo-create "$prepared" --server-id="$SERVER_ID"
  fi

  # 임시 파일 정리
  if [[ "$prepared" != "$config" ]]; then
    rm -f "$prepared"
  fi
}

CREATED_REPOS=()

for PKG_TYPE in maven pypi go; do
  echo "--- $PKG_TYPE 레포 생성 중 ---"
  for RCLASS in remote local virtual; do
    CONFIG="$SCRIPT_DIR/$PKG_TYPE/$RCLASS.json"
    REPO_KEY=$(jq -r '.key' "$CONFIG")
    create_or_update_repo "$CONFIG"
    CREATED_REPOS+=("$REPO_KEY")
  done
  echo ""
done

echo "=== 완료 ==="
echo ""
echo "다음 단계: Artifactory UI에서 각 가상 레포에 Curation 정책을 활성화하세요."
echo "  경로: Platform > Security & Compliance > Curation > Manage Policies"
echo ""
echo "생성된 레포 목록:"
for REPO in "${CREATED_REPOS[@]}"; do
  echo "  - $REPO"
done
