# JFrog Curation npm Demo

## 사전 준비

```bash
# 최초 1회만 실행 (이후 재로그인 불필요)
npm login --registry=https://<YOUR-ARTIFACTORY-URL>/artifactory/api/npm/<YOUR-NPM-VIRTUAL-REPO>/ --auth-type=web
```

`.npmrc` 가 이미 Curation이 적용된 `changwy-npm-virtual` 을 바라보도록 설정되어 있습니다.

---

## Case 1. CVE 차단 — `lodash@4.17.4`

**스토리**: 오래된 튜토리얼을 보고 구버전 lodash를 그대로 설치하려는 상황.

```bash
cd case1-cve
npm install
```

**예상 결과**: `403 Forbidden` — CVE-2019-10744 (Prototype Pollution, High)

**데모 포인트**:
- Artifactory UI → AppTrust/Curation → Activity Log에서 차단 이벤트 확인
- 정책 화면: CVE 점수, 영향 버전 범위 표시
- 안전 버전(`lodash@4.17.21`)으로 바꾸면 정상 설치됨

---

## Case 2. 신규 패키지 정책 차단 — `zod@4.4.2`

**스토리**: "새로 나온 zod 버전 써보려고 했는데..." (2026-05-01 퍼블리시, 14일 미만)

```bash
cd case2-new-package
npm install
```

**예상 결과**: `403 Forbidden` — package published 5 days ago, violates minimum age policy (14 days)

**데모 포인트**:
- Curation 정책: "퍼블리시된 지 14일 미만 패키지 차단"
- Activity Log에서 차단 이유: 퍼블리시 날짜 + 정책 기준 표시
- **핵심 메시지**: "악성 패키지의 90%는 퍼블리시 직후 수 시간 내 배포됨 — 14일 대기는 가장 단순하고 강력한 방어"
- 안전 버전(`zod@3.24.2` 등 오래된 버전)으로 바꾸면 정상 설치됨

---

## Case 3. 메인테이너 사보타주 차단 — `colors@1.4.44-liberty-2`

**스토리**: "외부 공격자가 아닌, 메인테이너 본인이 자기 패키지를 망가뜨린 사건." (2022년 1월)

```bash
cd case3-sabotage
npm install
```

**예상 결과**: `403 Forbidden` — malicious version (intentional maintainer sabotage)

**데모 포인트 (임팩트 최대화)**:
1. 먼저 차단 없이 어떤 일이 생기는지 직접 보여주기:
   ```bash
   # Curation 정책 일시 해제 후
   npm install
   node -e "require('colors')"
   # → "LIBERTY LIBERTY LIBERTY" 무한 출력 + 좀비 ASCII
   ```
2. Curation 켜고 다시 `npm install` → 즉시 차단
3. "이게 Curation 없을 때 일어나는 일입니다"

---

## Case 4. License (Transitive) 차단 — `@graphql-tools/schema@7.1.5`

**스토리**: "MIT 패키지만 넣었는데, 5단계 깊이에 GPL이 숨어 있다면?" (실제 Gatsby 사건, 2021년)

```bash
cd case4-license
npm install
```

**예상 결과**: `403 Forbidden` — `smartwrap@1.2.5` license GPL-2.0 violates policy

**의존성 트리 시각화** (차단 전에 보여주면 임팩트 있음):
```
@graphql-tools/schema@7.1.5
└─ value-or-promise
   └─ ...
      └─ smartwrap@1.2.5  ← GPL-2.0 ❌
```

**데모 포인트**:
- 직접 의존성은 모두 MIT — "보기엔 안전해 보입니다"
- Curation이 transitive 전체를 검사해서 라이선스 위반 감지
- 정책 화면: License allowlist (MIT / Apache-2.0 / BSD-* / ISC), GPL/AGPL 차단
- 안전 버전(`@graphql-tools/schema@7.1.3`)으로 핀 → 정상 설치

---

## 권장 발표 순서

| 순서 | 케이스 | 핵심 메시지 |
|------|--------|------------|
| 1 | Case 1 — lodash CVE | "알려진 취약점은 설치 자체가 안 됩니다" |
| 2 | Case 4 — License transitive | "직접 의존성만 보면 안전해 보이지만..." |
| 3 | Case 3 — colors 사보타주 | "메인테이너 신뢰만으론 부족합니다" (임팩트 절정) |
| 4 | Case 2 — zod 신규 패키지 | "악성 패키지의 90%는 퍼블리시 직후 배포됩니다" (정책 기반 방어) |

총 소요 시간: 약 15~20분
