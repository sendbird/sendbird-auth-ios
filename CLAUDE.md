- 배포 플로우에 대한 변경이 있을 땐 /script 안의 파일과 .claude/ 안의 skills.md 파일을 같이 수정할 것.
- co-author에 claude code를 등록하지 않을 것
- 코드 작성/수정 시 `team-claude/code_conventions.md` 의 컨벤션을 따를 것.
- 코드 컨벤션에 맞지 않는 패턴을 발견하면 기존 코드베이스 패턴에 맞게 수정할 것.
- 코드 작업 중 기존 컨벤션 문서에 없는 새로운 패턴이나 규칙을 발견하면, `team-claude/code_conventions.md`에 해당 내용을 자동으로 추가/업데이트할 것. 별도 요청 없이도 컨벤션 문서를 최신 상태로 유지할 것.
- **팀 메모리 실시간 업데이트**: 작업 중 아래 상황이 발생하면 즉시 해당 파일을 업데이트할 것:
  - 설계 결정 → `team-claude/features/[기능].md`의 Architecture 섹션에 기록
  - 버그 해결 → `team-claude/features/[기능].md`의 Solved Problems 섹션에 기록
  - 새로 알게 된 것 → `team-claude/features/[기능].md`의 Learnings 섹션에 기록
  - 반복될 수 있는 실수 발견 → `team-claude/common.md`의 Anti-patterns 섹션에 추가
  - 미해결 이슈 → `team-claude/features/[기능].md`의 Known Issues 섹션에 기록

## Team Memory System

팀 메모리는 `team-claude/` 디렉토리에 관리된다:

- `team-claude/code_conventions.md` — 전체 코드 컨벤션 (상세)
- `team-claude/common.md` — 팀 공통 핵심 규칙 (요약)
- `team-claude/features/` — 기능별 작업 메모리

## Feature Index

| 파일 | 기능 | 주요 디렉토리 |
|------|------|--------------|
| `features/connection.md` | WebSocket 연결 관리 (9-state 상태 머신) | `Sources/SendbirdAuth/Connection/` |
| `features/session.md` | 세션 관리 (session key, token expiration) | `Sources/SendbirdAuth/Session/` |
| `features/client.md` | HTTP/WebSocket 클라이언트 | `Sources/SendbirdAuth/Client/` |
| `features/stats.md` | 텔레메트리 (수집/전송) | `Sources/SendbirdAuth/Stats/` |
| `features/logger.md` | 로깅 시스템 (카테고리 기반) | `Sources/SendbirdAuth/Logger/` |
