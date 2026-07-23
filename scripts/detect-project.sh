#!/usr/bin/env bash
# Detects test/build/lint commands for the current project.
# Priority: Makefile > .claude/project-commands.json override > language markers > unknown (graceful degrade).
# Output: shell-sourceable KEY=VALUE lines (TEST_CMD, BUILD_CMD, LINT_CMD, PROJECT_TYPE).
# Any command that could not be determined is left empty — callers must handle that, not fail on it.

set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

TEST_CMD=""
BUILD_CMD=""
LINT_CMD=""
PROJECT_TYPE="unknown"

# Priority 0: Makefile — common lingua franca for polyglot/monorepo teams.
if [ -f "Makefile" ]; then
  grep -qE '^test:' Makefile && TEST_CMD="make test"
  grep -qE '^build:' Makefile && BUILD_CMD="make build"
  grep -qE '^lint:' Makefile && LINT_CMD="make lint"
  [ -n "$TEST_CMD$BUILD_CMD$LINT_CMD" ] && PROJECT_TYPE="makefile"
fi

# Priority 1: explicit project-local override — always wins over auto-detection below.
OVERRIDE_FILE=".claude/project-commands.json"
if [ -f "$OVERRIDE_FILE" ]; then
  command -v jq >/dev/null 2>&1 && HAS_JQ=1 || HAS_JQ=0
  if [ "$HAS_JQ" = "1" ]; then
    OV_TEST=$(jq -r '.test // empty' "$OVERRIDE_FILE")
    OV_BUILD=$(jq -r '.build // empty' "$OVERRIDE_FILE")
    OV_LINT=$(jq -r '.lint // empty' "$OVERRIDE_FILE")
    [ -n "$OV_TEST" ] && TEST_CMD="$OV_TEST"
    [ -n "$OV_BUILD" ] && BUILD_CMD="$OV_BUILD"
    [ -n "$OV_LINT" ] && LINT_CMD="$OV_LINT"
    PROJECT_TYPE="override"
  fi
fi

# Priority 2: language markers (only fill in gaps not already set by Makefile/override).
if [ "$PROJECT_TYPE" = "unknown" ] || [ "$PROJECT_TYPE" = "makefile" ]; then
  if [ -f "package.json" ]; then
    if [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
    elif [ -f "yarn.lock" ]; then PM="yarn"
    else PM="npm"
    fi
    [ -z "$TEST_CMD" ] && TEST_CMD="$PM test"
    [ -z "$BUILD_CMD" ] && BUILD_CMD="$PM run build"
    [ -z "$LINT_CMD" ] && LINT_CMD="$PM run lint"
    PROJECT_TYPE="node"
  elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
    [ -z "$TEST_CMD" ] && TEST_CMD="pytest"
    [ -z "$LINT_CMD" ] && command -v ruff >/dev/null 2>&1 && LINT_CMD="ruff check ."
    PROJECT_TYPE="python"
  elif [ -f "go.mod" ]; then
    [ -z "$TEST_CMD" ] && TEST_CMD="go test ./..."
    [ -z "$BUILD_CMD" ] && BUILD_CMD="go build ./..."
    [ -z "$LINT_CMD" ] && LINT_CMD="go vet ./..."
    PROJECT_TYPE="go"
  elif [ -f "pom.xml" ]; then
    [ -z "$TEST_CMD" ] && TEST_CMD="mvn test"
    [ -z "$BUILD_CMD" ] && BUILD_CMD="mvn package"
    PROJECT_TYPE="java-maven"
  elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    [ -z "$TEST_CMD" ] && TEST_CMD="gradle test"
    [ -z "$BUILD_CMD" ] && BUILD_CMD="gradle build"
    PROJECT_TYPE="java-gradle"
  elif [ -f "Cargo.toml" ]; then
    [ -z "$TEST_CMD" ] && TEST_CMD="cargo test"
    [ -z "$BUILD_CMD" ] && BUILD_CMD="cargo build"
    [ -z "$LINT_CMD" ] && LINT_CMD="cargo clippy"
    PROJECT_TYPE="rust"
  fi
fi

# Priority 3: nothing matched — this is NOT an error. Callers must degrade gracefully
# (skip the automated test gate with a warning) rather than blocking indefinitely.
if [ -z "$TEST_CMD" ] && [ "$PROJECT_TYPE" = "unknown" ]; then
  echo "PROJECT_TYPE=unknown"
  echo "TEST_CMD="
  echo "BUILD_CMD="
  echo "LINT_CMD="
  exit 0
fi

echo "PROJECT_TYPE=$PROJECT_TYPE"
echo "TEST_CMD=$TEST_CMD"
echo "BUILD_CMD=$BUILD_CMD"
echo "LINT_CMD=$LINT_CMD"
