# antigravity-plugin-cc

[English](./README.md) | **한국어**

Claude Code 안에서 [Antigravity](https://antigravity.google)(`agy`)를 사용해 **넓은 컨텍스트 기반 코드베이스 분석**을 수행합니다.

Antigravity의 Gemini 모델은 넓은 컨텍스트를 읽고 추론하는 데 강점이 있어, 대규모 코드베이스를 훑거나, 변경의 영향 범위를 추적하거나, 보안을 감사하거나, 대량 로그로부터 인프라 장애의 근본 원인을 찾는 작업에 잘 맞습니다. 이 플러그인은 그런 작업을 `agy` CLI에 위임하고, 무거운 분석 과정을 Claude Code 자신의 컨텍스트 밖에 두어 — 종합된 결과만 돌려받습니다. 이렇게 받은 결과는 곧바로 Claude나 Codex에 넘겨 후속 수정에 활용할 수 있습니다.

## 명령어

- `/agy:repo-scan <규칙 또는 영역>` — 저장소 전체 아키텍처 스캔. 코드베이스를 아키텍처 규칙과 대조해 레이어 위반, 잘못된 레이어 간 import, 순환 의존성을 `file:line` 인용과 함께 보고합니다.
- `/agy:impact-map <컴포넌트 또는 변경>` — 영향 범위(blast-radius) 분석. 핵심 컴포넌트에 대한 계획된 변경을 바깥으로 추적해 영향을 받는 모든 모듈, 설정, 테스트를 짚어주어 작업 시작 전에 부작용을 피할 수 있게 합니다.
- `/agy:sec-audit <가이드라인 또는 영역>` — 코드베이스 전체 보안 감사. 엔드포인트와 보안에 민감한 레이어를 스캔해 취약한 인증, 토큰 처리, 설정 문제를 찾아 각 발견 사항을 심각도와 `file:line`과 함께 보고합니다. 공용 Gemini 기본값 대신 `Claude Sonnet 4.6 (Thinking)`를 기본 모델로 사용하는데, Antigravity의 Gemini 모델이 보안 감사 요청을 거부하기 때문입니다(`--model`로 재정의 가능).
- `/agy:infra-debug <증상 또는 신호>` — 인프라 근본 원인 분석. Kubernetes 매니페스트, OpenTelemetry 설정, 대량 로그/트레이스 덤프를 상관 분석해 실패 경로가 어디서 끊기는지 짚고 수정 방향을 제시합니다.

모든 명령어는 선택적인 라우팅 플래그를 받습니다:

- `--model "<이름>"` — 기본 모델을 재정의합니다(`Gemini 3.5 Flash (High)`; `/agy:sec-audit`는 `Claude Sonnet 4.6 (Thinking)`가 기본). 유효한 이름은 `agy models`로 확인하세요.
- `--add-dir <경로>` — agy의 작업 공간에 다른 디렉터리를 추가합니다(반복 사용 가능). 현재 디렉터리는 항상 포함됩니다.

### 예시

```
/agy:repo-scan enforce hexagonal architecture — domain must not import infrastructure
/agy:impact-map I'm changing the Redis stream manager's serialization format
/agy:sec-audit check every endpoint for missing asymmetric JWT verification
/agy:infra-debug --add-dir ./logs distributed traces drop between gateway and order service
```

## 동작 방식

```
/agy:repo-scan | impact-map | sec-audit | infra-debug   (명령어, 요청을 구성)
        ↓  Agent 도구
agy:antigravity-explorer      (서브에이전트, 얇은 전달자 — 무거운 컨텍스트를 격리)
        ↓  antigravity-runtime 스킬
agy -p "<read-only로 감싼 프롬프트>" --add-dir "$PWD" \
       --model "Gemini 3.5 Flash (High)" \
       --dangerously-skip-permissions --print-timeout 9m
```

## 보안과 신뢰

이 플러그인은 `agy`를 `--dangerously-skip-permissions`로 실행하므로, **`agy`는 가리킨 디렉터리에 대해 읽기, 쓰기, 명령 실행 전권을 갖습니다.** 코드 위에서 자율 에이전트를 돌리는 것과 똑같이 취급하세요: **신뢰하는 코드에만 사용하세요.**

명령어는 `agy`에게 읽기 전용으로 동작하라고 *요청*합니다 — 프롬프트 지시문이 쓰기, 상태 변경 명령, 네트워크 접근을 금지하고 변경을 수행하는 대신 *설명*하라고 지시합니다. 이는 협조적인 모델의 우발적 편집은 확실히 막지만, **보안 경계는 아닙니다**: 프롬프트 인젝션이 된 작업 공간이나 적대적인 작업 공간이 파일을 쓰거나, 명령을 실행하거나, 데이터를 유출하는 것은 막지 못합니다. `agy`에는 읽기 전용 플래그가 없으며, `--dangerously-skip-permissions`도 `--sandbox`도 쓰기를 막지 못합니다(둘 다 실증 확인됨).

오늘 기준으로 확실한 읽기 전용 보장을 원한다면, `agy`를 직접 OS 수준 샌드박스(읽기 전용 파일시스템, 환경 변수에 비밀 정보 없음, 제한된 네트워크 송출)로 감싸세요.

## 로드맵

- **선택적 OS 수준 샌드박스** — 읽기 전용을 실제로 강제할 수 있게 합니다(예: macOS `sandbox-exec`). 프롬프트가 보장할 수 없는 요청이던 읽기 전용을 진짜 경계로 바꿉니다.

## 요구 사항

- [Antigravity CLI](https://antigravity.google)(`agy`)가 설치되고 인증되어 있어야 합니다. `agy --version`과 `agy models`로 확인하세요.

## 설치

```
/plugin marketplace add chanwoo040531/antigravity-plugin-cc
/plugin install agy@antigravity-plugin-cc
/reload-plugins
/agy:setup
```

`/reload-plugins`는 방금 설치한 플러그인을 현재 세션에서 활성화합니다 — 세션 도중에 설치한 플러그인은 자동으로 로드되지 않습니다(대신 Claude Code를 재시작해도 됩니다).

`/agy:setup`은 한 번만 실행하면 됩니다. `agy`가 설치·인증되어 있는지 확인한 뒤 `Bash(agy -p:*)` 권한 규칙을 Claude Code 설정에 추가합니다 — 만약 Claude Code의 auto-mode 분류기가 자동 편집을 막으면, 직접 추가할 수 있도록 해당 한 줄을 출력합니다(`/permissions`를 실행해 `Bash(agy -p:*)`를 허용해도 됩니다). 이 규칙이 없으면 분류기가 분석 명령어를 차단합니다: explorer 서브에이전트가 `agy -p … --dangerously-skip-permissions`를 실행하는데, 분류기가 이를 "unsafe agent"로 간주해 실행 전에 거부하기 때문입니다.

이 규칙이 무엇을 허용하는지 유의하세요: `Bash(agy -p:*)`는 해당 설정을 읽는 모든 Claude Code 세션에서 **모든** `agy -p` print-mode 호출을 자동 승인합니다 — 이 플러그인의 명령어만이 아닙니다(`disable-model-invocation`은 플러그인의 *명령어*가 자동 실행되는 것은 막지만, 권한의 범위를 좁히지는 않습니다). `agy -p`는 항상 `--dangerously-skip-permissions`를 동반하므로, 이는 "이 머신에서 `agy`가 매번 묻지 않고 실행되도록 신뢰한다"는 의도적인 선택입니다 — [보안과 신뢰](#보안과-신뢰) 섹션이 이미 요구하는 신뢰와 같습니다. 규칙을 머신 전체가 아니라 현재 저장소로 한정하려면 `--project`를 전달하세요.

## 라이선스

[MIT](./LICENSE)
