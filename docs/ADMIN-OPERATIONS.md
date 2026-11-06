# 서버 운영 안내

## 원클릭 실행

- 평소 실행: `HOST-SETUP-AND-RUN.cmd`
- 업데이트·백업 후 실행: `HOST-UPDATE-AND-RUN.cmd`
- 친구 배포 ZIP 생성: `MAKE-PLAYER-PACKAGE.cmd`
- 서버 암호 안전 복사: `COPY-SERVER-PASSWORD.cmd`
- DuckDNS 최초 등록·검증: `CONFIGURE-DUCKDNS.cmd`
- 고정 서버 암호 변경: `SET-SERVER-PASSWORD.cmd`
- 월드·캐릭터 초기화: `RESET-WORLD.cmd`
- 클라이언트 버전: Steam 최신 Stable 42.21.0 사용

세부 흐름은 [ONE-CLICK.md](ONE-CLICK.md)를 본다.

## 매회 시작 전

```powershell
.\scripts\preflight.ps1
.\scripts\validate-config.ps1
.\scripts\run-server.ps1 -ServerName escape_test
```

`SERVER STARTED` 후 친구를 받는다. 호스트 원클릭 경로에서는 DuckDNS가 시작 시와 서버 실행 중 5분마다 갱신된다. 종료는 창을 강제 종료하지 말고 콘솔에 `quit`을 입력한다.

## 업데이트

```powershell
.\scripts\update-server.ps1
.\scripts\run-server.ps1 -ServerName escape_test
# 정상 시작을 본 뒤 quit
.\scripts\check-logs.ps1 -RequireCleanShutdown
```

업데이트 스크립트는 설정·DB·세이브를 먼저 날짜별 ZIP으로 백업한다. 원클릭 업데이트 실행은 이 백업을 같은 실행의 설정 배포에서도 재사용해 전체 백업을 한 번만 수행한다. 일반 실행·최초 설치·설정 배포 단독 실행은 배포 전 기본 백업을 유지한다. `deploy-config.ps1 -SkipBackup`은 같은 실행에서 업데이트 전 백업을 마친 원클릭 호스트가 사용하는 옵션이다. 반복 실행 백업은 설치된 7-Zip의 빠른 압축을 우선 사용하며, OneDrive 폴더에 직접 압축하지 않고 `%LOCALAPPDATA%\PzEscapeServer\backup-staging`에서 완성·무결성 검사 후 `backups`로 이동한다. Steam/Workshop 업데이트 직후에는 본 캠페인을 열기 전에 `escape_test`로 검증한다.

## 클라이언트 버전

호스트와 플레이어 모두 Steam 최신 Stable 42.21.0을 사용한다. 예전 42.20.4 플레이어 ZIP이나 프로젝트 루트에 남아 있는 다운그레이드 도구는 보관용일 뿐이며 실행하지 않는다. Steam에서 게임을 업데이트한 뒤 메인 화면의 버전이 서버와 같은지 확인한다.

## 설정 변경

1. `config\escape_test`의 추적 파일만 편집한다.
2. `.\scripts\validate-config.ps1`을 실행한다.
3. `.\scripts\deploy-config.ps1 -ServerName escape_test`로 자동 백업 후 라이브 위치에 복사한다.
4. 부팅·종료 후 `.\scripts\check-logs.ps1 -RequireCleanShutdown`을 실행한다.

라이브 파일을 직접 수정하면 다음 배포 때 사라질 수 있다. `config\secrets.psd1`, 세이브, DB, 로그, Workshop payload는 커밋하지 않는다. 추적 INI의 빈 `Password=`는 정상이며 배포 스크립트가 비밀 파일의 고정 서버 암호를 라이브 INI에만 넣는다. DuckDNS 도메인과 token도 같은 비밀 파일에 저장되며 token은 친구 패키지에 들어가지 않는다.

`deploy-config.ps1`은 `custom-mods`의 서버 전용 모드도 `Zomboid\mods`로 배포한다. 탈출 진행이 막히면 관리자 캐릭터로 지면을 우클릭하고 `탈출 작전 관리자`에서 현재 단계 갱신·이전·다음·초기화를 사용한다. 캠페인 진행도만 초기화하려면 이 메뉴를 사용하고, 월드·캐릭터까지 지울 때만 `RESET-WORLD.cmd`를 사용한다.

퀘스트 방과 가전을 확정할 때는 [탈출 퀘스트 장소 답사·좌표 이동표](MISSION-SURVEY.md)를 따른다. 임시 관리자 권한으로 각 진입점에 순간이동한 뒤 실제 목표 방 안에서 `현재 방·주변 오브젝트 조사 기록`을 누르면 상세 정보가 서버 로그에 남는다.

현재 `escape_test`는 초보자가 많은 협동 플레이를 위해 좀비 기본 배율 `0.65`, 시작 배율 `0.5`, 최고 배율 `1.0`, `ZombieLore.Speed=4`, 스프린터 0%를 사용한다. 모든 샌드박스 값은 운영자가 자유롭게 조정할 수 있으며 `validate-config.ps1`은 특정 숫자나 활성화 여부를 강제하지 않는다. 따라서 잘못된 Lua 문법이나 게임·모드가 허용하지 않는 범위의 값은 서버 부팅 로그에서 확인해야 한다.

### 성장 및 음악 학습 완화 (2026-10-23)

운영 파일과 추적 샌드박스 파일에 `MultiplierConfig.GlobalToggle=false`, `Fitness=30.0`, `Strength=30.0`, 나머지 기술 배율 `10.0`, `Music.LearningChance=5`를 저장했다. 변경 전에는 `Global=10`, `GlobalToggle=true`여서 개별 기술의 `1.0` 값은 사용되지 않았다. 설치된 42.21.0 게임 코드의 경험치 계산은 전체 배율과 개별 배율 중 하나를 선택한다. 따라서 체력·근력을 현재보다 3배 완화하기 위해 개별 30배를 사용하고, 다른 기술은 기존 전체 10배와 같은 값을 유지한다. Lifestyle의 Art/Cleaning/Dancing/Meditation/Music 기술도 개별 10배로 맞춘다.

음악 학습은 ‘보통’(3)에서 ‘매우 쉬움’(5)으로 변경했다. 모드 코드상 판정 주사위에 +5가 추가되므로 음악 10레벨·Virtuoso 특성 없음·낮은 단계 미학습 곡 없음 기준 9~10레벨 곡 학습 확률은 유효 판정 1회당 1.5%에서 4%로 바뀐다. 이는 곡 재생 또는 클릭 1회당 확률이 아니다.

변경 스크립트는 `research/apply-progression-20261023.ps1`, 백업 경로와 전후 SHA256은 `research/progression-20261023-tracked.json` 및 `research/progression-20261023-live.json`에 기록했다. 기존 세이브·계정·모드·INI는 수정하지 않았다. 서버 프로세스는 종료하거나 재시작하지 않았으며 **다음 정상 서버 재시작 후 반영**된다. Lua 문법은 설치된 게임의 LuaCompiler로 운영/추적 파일 모두 통과했고, 저장소 설정 검증도 통과했다. 실제 운동 경험치 증가량과 클라이언트 학습 설정 반영은 재시작 후 확인해야 한다.

## Skully 회복·휘두르기·임시 패치 조합 (2026-10-24)

기존 회복 모듈만 사용하던 구성에서 다음 세 모듈을 순서대로 사용한다.

1. `SkullysFasterAttackSpeed` — Workshop `3702483515`.
2. `SkullysFasterSwingSpeed` — 같은 Workshop의 별도 모듈.
3. `SkullysAttackSwingSpeed4217TempFix` — Workshop `3719586369`, 버전 `0.1.0-42.17-tempfix2`.

임시 패치는 두 원본 모듈 뒤에서 XML과 동일 상대경로 Lua를 덮어쓴다. 주요 공격 BlendOutTime을 0.25로 복구하고 한손/양손 후속 딜레이를 각각 2/3으로 줄이며 Idle 전환도 단축한다. 일반/Heavy 공속 상한은 1.40/1.55이고 현재 Firesparks 보정이 뒤에 적용되면 1.43/1.58이 될 수 있다. 칼 애니메이션은 고정 1.25로 바뀐다. 제작자 페이지의 목표는 42.17이며 42.21의 실제 멀티 명중은 별도 확인한다. 사용 여부가 확인되지 않은 구형 칼 마무리 분기의 시간 역전도 아직 실전 검증하지 않았다.

설정은 Mods 103개 / Workshop 94개다. `prepare-skully-combo-20261024.ps1`은 두 INI의 Mods/WorkshopItems만 준비하고 기존 설정을 백업한다. `apply-skully-combo-20261024.ps1`은 전체 월드 백업 → 새 Workshop 항목만 캐시 설치 → 별도 캐시·새 월드·포트 30461/30462의 비Steam 서버 부팅 및 정상 종료 → 운영 INI 반영 순서로 진행한다. 운영 서버를 자동 시작하지 않으며 기존 샌드박스, 계정 DB, 플레이어/차량 DB, global mod data는 보존한다. 기록은 `research/skully-combo-20261024/plan.json`과 같은 폴더의 로그를 따른다.

검증 상태: 설정 명세 및 새 플레이어 ZIP의 모드 순서·런처 TestOnly 검증 통과. 42.21.0 격리 서버에서 세 모듈 로드, 패치 XML 5개와 Lua 덮어쓰기, SERVER STARTED, 정상 종료 및 종료 코드 0을 확인하고 운영 INI에 반영했다. 샌드박스·계정 DB·플레이어/차량 DB·global mod data 해시는 유지됐으며 운영 서버는 꺼진 상태다. 실제 멀티플레이 명중은 게임 안에서 확인해야 한다. 최초 정션 기반 테스트는 경로 해석 문제로 실패했으며, 통과한 테스트는 모드 파일을 별도 폴더에 직접 복사했다.

참가자는 서버와 게임을 완전히 종료한 뒤 다시 실행해야 하며, 새 Workshop 항목은 서버 접속 과정에서 Steam이 다운로드한다. 업데이트된 로컬 참가자 ZIP은 `packages/pz-escape-player-16261.zip`이다. 이 변경에는 자체 모드 코드 변경이 없으며, 공개 서명 업데이트 피드/새 GitHub 릴리스는 변경하지 않는다. 기존 공개 런처의 허용 모드 목록은 이전 버전일 수 있지만 실제 접속 모드는 서버의 Workshop/Mods 목록으로 전달된다. 전역 모드 검사와 관련하여 목록 갱신이 필요하면 새 ZIP을 사용할 수 있으나, 부트스트랩의 공개 자동 업데이트는 기존 서명 배포를 따르는 점을 구분한다.

되돌릴 때는 서버·게임을 정상 종료한 후 plan.json에 기록된 설정 백업을 검토해 INI와 명세를 복구한다. 설치 캐시는 다른 서버에 영향을 줄 수 있으므로 제거할 필요가 없다. 이 변경의 되돌리기에 월드 초기화는 필요 없다.

## Jumbo Tree Indoor Fix 제거 (2026-10-18)

서버를 정상 종료한 상태에서 INI의 `Mods`에서 `JumboTreeIndoorFix`, `WorkshopItems`에서 `3774826484`를 함께 제거한다. 다른 모드와 `DoLuaChecksum=true`는 유지한다. 플레이어용 서명 배포의 `server-mods.json`도 갱신해 기존 `JOIN-SERVER.cmd`가 새 목록을 받도록 한다. Steam 구독 파일은 남겨도 되며 월드·캐릭터 초기화는 필요 없다. 플레이어는 게임을 완전히 종료하고 런처를 다시 실행한다. 개인 전역 활성 모드에 Jumbo Tree가 남아 있으면 새 목록의 검사에서 `Y`로 백업·정리하거나 게임 모드 메뉴에서 해당 모드만 비활성화한다. 런처의 `Y`는 전역 활성 모드 전체를 정리하므로 개인 구성을 유지하려면 직접 해당 모드만 끈다. 이전 목록의 검사 상태는 새 모드 목록 지문과 달라 자동 재검사된다. 이 제거 자체로 42.21의 바닐라 나무 렌더링 오류 해결을 보장하지는 않는다. 근거와 활성 목록은 [MODS.md](../MODS.md)를 따른다.

## 월드 초기화

1. 서버 콘솔에서 `quit`을 입력하고 창이 완전히 닫힐 때까지 기다린다.
2. 프로젝트 루트의 `RESET-WORLD.cmd`를 더블클릭한다.
3. 화면에 표시된 서버 이름을 똑같이 입력해 확인한다.
4. 완료 메시지와 생성된 ZIP 백업 경로를 확인한다.
5. `HOST-SETUP-AND-RUN.cmd`를 실행해 새 월드를 생성한다.

초기화 스크립트는 실행 중인 전용 서버를 감지하면 중단하고, 먼저 `backups` 폴더에 설정·계정 DB·월드를 묶은 ZIP을 만든다. 이후 `Saves\Multiplayer\escape_test`만 제거하고 추적·라이브 INI의 `ResetID`를 함께 변경한다. 월드 안의 캐릭터 DB도 초기화되지만 외부 `db\escape_test.db`의 접속 계정과 서버 설정, 모드, DDNS, 비밀번호는 유지된다.

## 장애 대응

- 새 모드 묶음 직후 실패: 마지막 묶음만 절반씩 비활성화해 원인을 찾는다.
- 체크섬 오류: `DoLuaChecksum=false`로 우회하지 말고 서버/클라이언트 Workshop 버전과 Mod ID를 맞춘다.
- 업데이트 후 월드 오류: 서버를 멈추고 가장 최근 백업의 해시와 내용을 확인한 뒤 복구 여부를 결정한다.
- 포트 바인딩 실패: 다른 서버 프로세스가 16261/16262를 쓰는지 확인한다.
- 로그 기준: `SERVER STARTED` 1회, `Shutdown handling finished` 1회, fatal/mod failure 0회를 요구한다.

## 2026-11-06 시작 백업 가속

기존 백업은 그대로 두고, 다음 ZIP을 복사본에서 변경 파일만 갱신하는 독립형 전체 스냅샷으로 생성한다. 전체 CRC·SHA-256·삭제 반영 검증은 유지한다. 실제 16:00 백업을 검증해 기준으로 등록했다. 인덱스가 유효하지 않으면 전체 백업으로 돌아간다. [상세 동작·복구 범위·검증](SERVER-START-BACKUP-20261106.md).

