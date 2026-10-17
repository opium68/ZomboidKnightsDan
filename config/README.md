# 설정 관리 정책

이 폴더의 `escape_test` 파일이 서버 설정의 추적 정본이다. 라이브 `%USERPROFILE%\Zomboid\Server`, DB, 세이브, 비밀번호, RCON 자격 증명, 접근 목록은 Git 밖에 둔다.

안티치트 10개 항목은 모두 `3`(위반 로그만 기록)으로 설정한다. 안티치트 판정으로 자동 밴이나 킥을 하지 않으며, 이전에 비활성화한 벽 관통·패킷 오류 검사도 로그 기록으로 전환한다. `DoLuaChecksum=true`의 파일 일치 검사와 수동 관리자 처분은 별도 설정이다.

`SafehouseAllowNonResidential=true`로 비주거 건물도 은신처 지정을 허용한다(2026-10-17 승인). 다른 은신처 지정 조건은 유지한다. 이는 타일의 방/건물 메타데이터나 수도 급수 조건을 바꾸지 않는다. 실행 중에는 관리자 채팅 `/changeoption SafehouseAllowNonResidential true`로 적용할 수 있다. 자체 패치 적용 스크립트도 서버·게임 종료 확인 후 이 항목을 추적 정본과 일치시킨다.

급수 문제 진단 중 `LGExtendedPlumbing.Enabled=false`를 추적 SandboxVars에도 유지한다. 원클릭 서버 시작은 추적 설정을 운영 경로로 복사하므로 게임에서만 바꾼 값은 다음 시작에 덮어써질 수 있다. 배관 재활성화는 진단 후 운영 파일과 추적 정본을 함께 변경한다.

경로를 바꿀 때만 `paths.example.psd1`을 무시되는 `paths.psd1`로 복사한다. 관리자 초기 암호, 고정 서버 접속 암호, DuckDNS 도메인과 token은 무시되는 `secrets.psd1`에만 둔다. 추적 INI의 `Password=`는 의도적으로 비어 있고 `deploy-config.ps1`이 라이브 INI에만 암호를 주입한다. `CONFIGURE-DUCKDNS.cmd`와 `SET-SERVER-PASSWORD.cmd`가 이 파일을 안전하게 갱신한다. 수정 후 `validate-config.ps1`, `deploy-config.ps1`, 부팅, `check-logs.ps1` 순서로 검증한다.
