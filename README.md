# FRCTL//SWARM — Gate A Prototype

`FRCTL_SWARM_GDD.md`의 1주 차 Gate A를 플레이 가능한 Godot 4 프로젝트로 구현한 회색 상자 프로토타입입니다. 외부 이미지·폰트·사운드 없이 Godot 기본 드로잉만 사용합니다.

## Web prototype

`docs/`에는 GitHub Pages에서 바로 실행할 수 있는 HTML5 Canvas 버전이 포함되어 있습니다. Godot 버전과 같은 Gate A 루프인 이동, 블링크, PULSE 자동 공격, 에너지 선택, MITOSIS, DELTA 편대, 3분 결과 화면을 브라우저 API만으로 구현했습니다.

로컬 미리보기:

```bash
python3 -m http.server 8765 --directory docs
```

그런 다음 브라우저에서 `http://127.0.0.1:8765`를 엽니다. 데스크톱에서는 키보드, 터치 환경에서는 화면 하단 방향 버튼과 BLINK 버튼을 사용할 수 있습니다. 최고 점수는 브라우저의 `localStorage`에 저장됩니다.

## 실행

Godot 4.x에서 저장소 루트의 `project.godot`을 연 뒤 **F6이 아니라 F5**로 메인 프로젝트를 실행합니다.

터미널 실행 예시(macOS):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## 조작

- 이동: `WASD` 또는 방향키
- 블링크: `Space`
- 업그레이드 선택: 마우스 또는 `1`·`2`·`3`
- 일시 정지: `Esc`
- 결과 화면 재시작: `Enter`, `Space`, `R` 또는 버튼

공격은 자동입니다. 붉은 CHASER를 처치하면 황색 에너지가 떨어지고, 가까이 가면 흡수됩니다.

## 구현 상태

- 16:9 단일 아레나와 3분 런
- 5칸 체력, 피격 무적, 이동 방향 블링크와 재사용 링
- 풀링된 CHASER, PULSE 탄환, 에너지 조각
- PULSE `●` 2기 시작과 가장 가까운 적 자동 공격
- 에너지 레벨업과 게임을 멈추는 수식 3지선다
- 첫 선택에 고정 노출되는 `MITOSIS — ● → ●●`
- MITOSIS 선택 후 PULSE 8킬마다 복제, 최대 5회
- 3기부터 `DELTA` 삼각 편대와 탄환 관통 +1
- 점수, 위험 배율, STABLE 배율, CLOSE CALL 표시
- FPS·적·유닛·탄환 수 디버그 HUD
- 승리/패배, 최종 공식, 최고 점수, 한 입력 재시작
- 코드 드로잉 기반 그리드·잔상·히트·수식 발동 연출

프로토타입의 추가 선택지(`ACCELERATE`, `AMPLIFY`, `BINARY`, `VECTORING`, `REPAIR`)는 3지선다와 빌드 변화의 감각을 검증하기 위한 최소 효과입니다. 전체 GDD의 12개 규칙을 구현한 범위는 아닙니다.

## 자동 검증

Godot 설치 환경에서 다음 smoke test를 실행할 수 있습니다.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke_test.gd
```

테스트는 씬 초기화, 이동, 블링크, 탄환 처치, MITOSIS 복제, DELTA 전환, 3개 업그레이드 후보 생성을 확인합니다.

3분 전체 런을 가속 재생해 풀링·난이도 증가·레벨업·MITOSIS 상한·승리 전환을 확인하려면 다음을 실행합니다.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/full_run_test.gd
```

## 주요 수치 수정

플레이어, 적, 편대, 탄환, 경험치와 런 시간의 수치는 `scripts/core/game_config.gd`에 모여 있습니다.

현재 밸런싱 목표는 첫 레벨업 약 30–40초, MITOSIS 선택 시 첫 복제 약 45–55초입니다. 실제 플레이테스트에서 첫 레벨업과 첫 복제 시간을 우선 기록해 `SPAWN_RATE_START`, `FIRST_LEVEL_XP`, `XP_GROWTH`를 조정하면 됩니다.

## 다음 작업

Gate A의 재미를 먼저 확인합니다. `●` 2기 → MITOSIS → 3기 DELTA 전환이 60초 안에 명확하고 만족스럽게 느껴지는지 검증한 뒤, Gate B의 `▲`, `■`, 나머지 편대와 전체 12개 규칙으로 확장합니다.

## 알려진 제한

- 현재 적은 Gate A 범위의 CHASER 한 종류입니다.
- 합성 사운드, 게임패드 UI 탐색 세부 조정, 보스 `NULL`은 이후 범위입니다.
- 적/탄환/에너지는 풀링하지만 PULSE는 최대 30기라 런 중 직접 생성합니다.
- 웹 버전은 배포 파일 크기와 GitHub Pages 호환성을 위해 Godot WebAssembly export가 아닌 Canvas 런타임 포트입니다.
