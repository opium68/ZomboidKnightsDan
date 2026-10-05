녹스 탈출 서버 접속 런처
=========================

처음 이용한다면 OPEN-MANUAL.cmd를 더블클릭해 쉬운 접속 및 모드 안내서를 먼저 읽으세요.

1. ZIP의 압축을 전부 풉니다.
2. Steam에 로그인합니다.
3. Steam에서 Project Zomboid를 최신 Stable 42.21.0으로 업데이트합니다.
4. JOIN-SERVER.cmd를 더블클릭합니다.
5. 동봉된 Knox Escape Quest 서버 전용 모드를 자동 설치합니다.
6. 최초 실행 시 서버 모드와 PC의 전역 활성 모드를 비교합니다.
7. 서버에 없는 모드가 있으면 Y(백업 후 정리) 또는 N(유지)을 선택합니다.
8. Project Zomboid가 열리면 공용 서버 암호를 입력합니다.
9. 자신만의 계정 이름과 계정 암호를 새로 만듭니다.
10. 게임에서 암호 저장을 선택하면 다음 접속이 더 간단해집니다.

주소가 바뀌면 RESET-SERVER-ADDRESS.cmd를 실행하세요.
모드를 다시 검사하려면 CHECK-CLIENT-MODS.cmd를 실행하세요.
정리 전에 쓰던 전역 모드 목록을 되돌리려면 RESTORE-CLIENT-MODS.cmd를 실행하세요.
예전 플레이어 ZIP에 들어 있는 DOWNGRADE-CLIENT-TO-42.20.4.cmd는 실행하지 마세요.

Y를 선택하면 Zomboid\mods\default.txt를 날짜별 파일로 백업한 뒤 전역 모드를 모두
비활성화합니다. 서버에 필요한 모드는 접속 과정에서 서버 목록대로 불러옵니다.
local-mods 폴더에는 이 서버 전용 탈출 모드가 들어 있습니다. player-settings.json에는
주소와 포트만, server-mods.json에는 공개 Mod/Workshop ID만 들어 있으며 비밀번호와
DuckDNS token은 저장되지 않습니다.

주의: Project Zomboid의 +connect 기능은 서버 주소까지 자동 전달하지만,
비공개 서버의 계정 선택과 암호 입력을 외부 스크립트가 안전하게 대신할 수는 없습니다.
