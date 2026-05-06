# JFrog Curation vs Xray — 비교 데모

OSS 패키지 보안의 두 축인 **JFrog Curation**(출입문 차단)과 **JFrog Xray**(내부 지속 감시)의 역할 차이를 시각화한 데모.

## 보기

- 애니메이션: [index.html](./index.html) — 패키지 입고 / Curation 검문 / Xray 순찰 / CVE 발견 → 격리 → 패치까지의 라이프사이클
- 정지 이미지: [still.html](./still.html) — CVE 발견 순간을 한 프레임으로 정리

GitHub Pages: https://changwy-jfrog.github.io/npm-curation-demo/

## 시나리오

1. **Curation (출입문 경비)**: 외부 레지스트리(npm/PyPI/Maven/Docker Hub/Hugging Face 등)에서 들어오는 패키지를 정책 기반으로 사전 차단
2. **Xray (내부 보안요원)**: 이미 저장된 아티팩트를 끊임없이 순찰 스캔, 신규 CVE 공개 시 영향받는 위치 즉시 식별
3. **CVE 대응**: log4j-core 2.14.1 → CVE-2021-44228 (Log4Shell) 발견 → 격리 → 2.17.1 패치 권고 → 해결
