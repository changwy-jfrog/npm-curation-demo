# JFrog Curation Multi-Ecosystem Demo

JFrog Curation이 **npm / Maven / PyPI / Go** 4개 에코시스템에서 동일한 정책으로 악성·위험 패키지를 차단하는 것을 시연합니다.  
모든 예제는 [SolEng CoE CVS Newsletter]에 기록된 실제 프로덕션 차단 사례입니다.

---

## 사전 준비

### 1단계: Artifactory 레포 생성 (최초 1회 — JFrog 관리자)

`setup/` 폴더의 스크립트로 Maven / PyPI / Go 가상 레포를 일괄 생성합니다.

```bash
cd setup
./setup-repos.sh               # All Projects에 생성
# 또는
./setup-repos.sh --project changwy  # 특정 프로젝트에 생성
```

이미 레포가 있다면 이 단계를 건너뛰세요.

### 2단계: JFrog CLI 설정 (최초 1회)

```bash
jf config add solenglatest \
  --url=https://solenglatest.jfrog.io \
  --user=<YOUR-EMAIL> \
  --password=<YOUR-TOKEN>
```

### 3단계: 에코시스템별 클라이언트 설정 (최초 1회)

**npm**
```bash
npm login --registry=https://solenglatest.jfrog.io/artifactory/api/npm/changwy-npm-virtual/ --auth-type=web
```
`.npmrc`가 이미 `changwy-npm-virtual`을 바라보도록 설정되어 있습니다.

**Maven**
```bash
jf mvn-config --global --server-id-resolve=solenglatest --repo-resolve-releases=changwy-maven-virtual
```

**PyPI**
```bash
jf pip-config --global --server-id-resolve=solenglatest --repo-resolve=changwy-pypi-virtual
```

**Go**
```bash
jf go-config --global --server-id-resolve=solenglatest --repo-resolve=changwy-go-virtual
```

---

## Case 목록

| Case | Curation 조건 | 에코시스템 | 차단 패키지 | 허용 버전 |
|------|--------------|-----------|------------|---------|
| [1](#case-1-cve-차단) | Known CVE | npm | `lodash@4.17.23` | `4.17.21` |
| [2](#case-2-악성-패키지) | Malicious Package | npm | `ansi-styles@6.2.2` | `6.1.1` |
| [3](#case-3-미성숙-7일) | Immature 7 Day | npm | `@aws-sdk/client-eventbridge@3.1039.0` | `3.1037.0` |
| [4](#case-4-미성숙-14일) | Immature 14 Day | npm, PyPI | `cssnano@7.1.7` / `anthropic==0.97.0` | `7.1.5` / `0.96.0` |
| [5](#case-5-미성숙-cve-예외) | Immature except CVE 7+ Fix | npm, PyPI | `@ant-design/icons@6.2.0` / `boto3-stubs==1.42.92` | `6.1.1` / `1.42.91` |
| [6](#case-6-업데이트-보류) | Package Pending Update | npm+Maven+PyPI+Go | `rc@2.3.9` / `flyway-firebird:12.5.0` / `google-cloud-trace==1.19.0` / `grpc@v1.81.0` | 각 이전 버전 |
| [7](#case-7-cve-수정판-차단) | Block High CVE with Fix | Go | `gopkg.in/src-d/go-git.v4@v4.1.0` | `v4.0.0-rc9` |
| [8](#case-8-라이선스-위반) | License Violation (Transitive) | npm | `imagemin-pngquant@10.0.0` | — |

---

## 차단 결과 해석 — 두 가지 메커니즘

JFrog Curation은 정책 종류에 따라 두 가지 방식으로 차단합니다.

| 차단 방식 | 적용 정책 | npm 클라이언트가 보는 에러 |
|---------|---------|--------------------------|
| **403 Forbidden** | Known CVE, Malicious Package | `npm error code E403` |
| **메타데이터 필터링** | Immature, Pending Update, License | `npm error code ETARGET` (No matching version found) |

> **ETARGET은 정상 동작입니다.** Curation이 가상 레포의 메타데이터에서 차단 버전을 제거하기 때문에, npm 클라이언트는 "그 버전 자체가 존재하지 않는다"고 인식합니다. PyPI는 `Could not find a version`, Maven/Go는 resolve 실패 형태로 동일 패턴을 보입니다.

## Curation Audit 출력 보는 법

`jf npm install`은 인증이 추가된 `npm install` 래퍼일 뿐이라 audit 결과를 출력하지 않습니다. 차단 이유와 정책을 직접 확인하려면 다음 두 가지를 사용하세요.

**클라이언트 사이드 — 데모에 가장 효과적**
```bash
cd case1-cve
jf curation-audit          # alias: jf ca
```
의존성 트리를 스캔해 차단 패키지와 정책 이유를 표시합니다. **install 전에 audit을 먼저 보여주는 흐름**을 권장합니다.

**서버 사이드**
JFrog Platform → **Curation → Activity Log** — 실시간 차단 기록 (요청자, 정책, 시각 포함).

---

## Case 1. CVE 차단 — `lodash@4.17.23` (npm)

**스토리**: 오래된 튜토리얼을 보고 구버전 lodash를 그대로 설치하려는 상황.

```bash
cd case1-cve
jf npm install
```

**예상 결과**: `npm error code E403` — CVE-2020-8203 (Prototype Pollution, CVSS 7.4)

**데모 포인트**:
- `jf curation-audit` 또는 Curation Activity Log에서 CVE 정보 + 차단 이유 확인
- `lodash@4.17.21`으로 변경하면 정상 설치

---

## Case 2. 악성 패키지 — `ansi-styles@6.2.2` (npm)

**스토리**: 유명 패키지와 동일한 이름, 악성 버전이 npm에 업로드됨. JFrog Research가 탐지하여 차단.

```bash
cd case2-malicious
jf npm install
```

**예상 결과**: `npm error code E403` — Malicious package flagged by JFrog Research

**데모 포인트**:
- CVE가 없어도 악성 행위(코드 인젝션, 환경변수 탈취 등)로 차단 가능
- JFrog Research 팀의 실시간 탐지 결과가 Curation 정책에 반영됨
- `ansi-styles@6.1.1`로 변경하면 정상 설치

---

## Case 3. 미성숙 7일 — `@aws-sdk/client-eventbridge@3.1039.0` (npm)

**스토리**: AWS SDK 최신 버전을 바로 적용하려는 개발자. 출시 7일 미만이라 차단됨.

```bash
cd case3-immature-7d
jf npm install
```

**예상 결과**: `npm error code ETARGET` — 메타데이터 필터링으로 차단 버전이 제거됨. `jf curation-audit`로 정책 이유(Published less than 7 days ago) 확인.

**데모 포인트**:
- **핵심 메시지**: "악성 npm 패키지의 대다수는 퍼블리시 후 수 시간 내 배포됨"
- 이름이 알려진 패키지라도 새 버전은 차단 — 타이포스쿼팅·버전 하이재킹 방어
- `@aws-sdk/client-eventbridge@3.1037.0`으로 변경하면 정상 설치

---

## Case 4. 미성숙 14일 — `cssnano@7.1.7` (npm) / `anthropic==0.97.0` (PyPI)

**스토리**: 빌드 파이프라인에서 CSS 최적화 라이브러리 최신 버전을 자동으로 끌어오는 상황. PyPI에서는 Anthropic SDK 최신 버전 사용 시도.

```bash
cd case4-immature-14d

# npm
jf npm install

# PyPI
jf pip install -r requirements.txt
```

**예상 결과**:
- npm: `npm error code ETARGET` (cssnano@7.1.7 메타데이터 필터링)
- PyPI: `ERROR: Could not find a version that satisfies the requirement anthropic==0.97.0`
- 두 에코시스템 모두 정책: *Package published less than 14 days ago*

**데모 포인트**:
- 동일한 정책이 **npm과 PyPI 모두에** 적용됨을 한 폴더에서 시연
- 에코시스템이 달라도 Curation 정책 관리 포인트는 하나

---

## Case 5. 미성숙 (CVE 예외) — `@ant-design/icons@6.2.0` (npm) / `boto3-stubs==1.42.92` (PyPI)

**스토리**: "새 버전이 나왔는데 CVE 픽스가 포함됐다면 바로 써도 되지 않나요?"  
→ 정책이 미성숙 차단이지만, **CVSS 7.0 이상 CVE 수정 버전은 예외 허용**.  
→ 이 버전은 CVE 픽스가 없으므로 차단.

```bash
cd case5-immature-cve-ex

# npm
jf npm install

# PyPI
jf pip install -r requirements.txt
```

**예상 결과**:
- npm: `npm error code ETARGET` (@ant-design/icons@6.2.0 메타데이터 필터링)
- PyPI: `ERROR: Could not find a version that satisfies the requirement boto3-stubs==1.42.92`
- 정책: *Package immature and does not fix a CVE with severity ≥ 7*

**데모 포인트**:
- "무조건 차단"이 아닌 **정교한 정책** — 보안 픽스는 즉시 통과, 일반 업데이트는 대기
- 개발자 생산성과 보안의 균형을 자동화로 해결

---

## Case 6. 업데이트 보류 — 4개 에코시스템 동시 시연

**스토리**: 팀이 각자 다른 언어로 서비스를 개발 중. 모두 "최신 버전"을 쓰려 했지만 각 버전은 내부 검토 중(Pending Update).

```bash
cd case6-pending-update

# npm — rc@2.3.9 (safe: 1.2.7)
jf npm install

# Maven — org.flywaydb:flyway-firebird:12.5.0 (safe: 12.4.0)
jf mvn dependency:resolve

# PyPI — google-cloud-trace==1.19.0 (safe: 1.18.0)
jf pip install -r requirements.txt

# Go — google.golang.org/grpc@v1.81.0 (safe: v1.80.0)
jf go get google.golang.org/grpc@v1.81.0
```

**예상 결과**: 4개 명령 모두 *Package Pending Update* 정책으로 차단 — 클라이언트별 메시지는 다음과 같음
- npm: `npm error code ETARGET` (rc@2.3.9 메타데이터 필터링)
- Maven: `Could not find artifact org.flywaydb:flyway-firebird:jar:12.5.0`
- PyPI: `ERROR: Could not find a version that satisfies the requirement google-cloud-trace==1.19.0`
- Go: `module ... not found` 또는 resolve 실패

**데모 포인트**:
- **가장 임팩트 있는 케이스** — 언어/에코시스템에 무관하게 동일한 정책이 적용됨을 순차적으로 시연
- "Curation은 npm만이 아닙니다"

---

## Case 7. CVE 수정판 차단 — `gopkg.in/src-d/go-git.v4@v4.1.0` (Go)

**스토리**: Go git 라이브러리를 업데이트했는데, v4.1.0 이후 버전 전체에 고위험 CVE가 존재하고 수정된 버전도 없음. 16개 이상 버전이 일괄 차단.

```bash
cd case7-cve-with-fix
jf go get gopkg.in/src-d/go-git.v4@v4.1.0
```

**예상 결과**: Go module resolve 실패 — Curation이 v4.1.0 이상의 메타데이터를 필터링 (정책: *Block new high CVEs that have fix*, 적용 범위 v4.1.0 ~ v4.12.0+)

**데모 포인트**:
- "픽스가 있는데도 CVE 버전을 쓰는" 상황을 자동으로 차단
- 단일 패키지에서 16개 이상의 버전이 동시에 차단되는 범위를 Activity Log에서 확인
- Safe version: `v4.0.0-rc9`

---

## Case 8. 라이선스 위반 (Transitive) — `imagemin-pngquant@10.0.0` (npm)

**스토리**: 이미지 최적화 플러그인 하나를 추가했는데, GPL이 transitive 의존성으로 딸려 들어옴. (실제 gatsby-plugin-sharp 사건, 2019년)

```bash
cd case8-license
jf npm install
```

**예상 결과**: `npm error code ETARGET` 또는 transitive resolve 실패 — `pngquant-bin@9.x` (GPL-3.0)이 메타데이터 필터링으로 제거됨. `jf curation-audit`로 라이선스 위반 transitive 경로 확인.

**의존성 트리**:
```
imagemin-pngquant@10.0.0  ← MIT (직접 의존성 — 안전해 보임)
└─ pngquant-bin@9.x       ← GPL-3.0 ❌ (transitive)
```

**데모 포인트**:
- 직접 의존성은 MIT — "보기엔 안전합니다"
- Curation이 transitive 전체를 스캔해 GPL 탐지
- GPL 코드가 포함된 앱을 배포하면 소스코드 공개 의무 발생 → 법적 리스크

---

## 권장 발표 순서

| 순서 | Case | 핵심 메시지 |
|------|------|------------|
| 1 | Case 1 — lodash CVE | "알려진 취약점은 설치 자체가 안 됩니다" |
| 2 | Case 8 — License transitive | "직접 의존성만 보면 안전해 보이지만..." |
| 3 | Case 2 — ansi-styles malicious | "CVE 없이도, 악성 행위 자체로 차단됩니다" |
| 4 | Case 6 — Pending Update (4 ecosystems) | "언어가 달라도 정책은 하나입니다" (클라이맥스) |
| 5 | Case 3/4/5 — Immature | "새 버전도 검증 전엔 통과 불가 — 정교하게 조정 가능" |
| 6 | Case 7 — CVE with fix (Go) | "수정 버전이 있는데 구버전을 쓰는 것도 차단" |

총 소요 시간: 약 20~30분
