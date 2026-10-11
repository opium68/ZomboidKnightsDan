# TTAJ 의류 검토·추가

2026-10-12: 사용자 지정 후보 세 개를 검토했다. 검증 후 운영 적용했다.

| 모드 | 최근 보고와 판단 | 판매 세트 |
|---|---|---|
| [Militek Faction Clothing](https://steamcommunity.com/sharedfiles/filedetails/?id=3269061047) | 8월 15일 저자 업데이트로 방탄복·재킷 동시 착용 문제 수정. 내복 아이콘 및 가슴 파우치 모델 문제를 피하도록 해당 품목은 제외 | 일반 중장갑 $225,000 / 장교 중장갑 $270,000 |
| [Japanese Traditional Outfit](https://steamcommunity.com/sharedfiles/filedetails/?id=3283211180) | 42.13 멀티 업데이트 이후 7월 31일 42.20 정상 동작 댓글. 최근 미해결 기능 오류를 찾지 못함 | 검정 하오리·베이지 속옷·갈색 하카마·흰 허리띠·검정 양말·짚 샌들 $30,000 |
| [Lynx Pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3470485566) | 9월 과도한 필드 생성 보고는 보상 전용 차단으로 대응. 8월 Alice Weapon Sling 충돌 의심은 해당 저자가 재현하지 못했으며 서버에 해당 모드 없음 | 검정 전술 8종 $180,000 |

가격은 기존 세트의 성능별 가격대와 3배 정책에 맞췄다. 기존 21개에 4개를 더해 총 25개 세트다. 원본은 Steam Workshop에서 개별 설치하며 배포 ZIP에는 넣지 않는다.

모든 신규 아이템의 자연 생성과 원본 제조를 기존 보상 전용 필터에 등록한다. 밀리텍·하오리의 OnInitGlobalModData 생성 콜백 이후에도 필터가 실행되도록 자체 패치는 마지막 순서로 로드한다. 기존 소유품과 결제한 주문은 유지한다.

검증 결과는 아래에 기록한다. 멀티 플레이의 남녀 착용 외형·실제 우편 수령은 별도 게임 확인이 필요하다. 당일 고정 추첨·의류 슬롯 제한은 이번 변경에 포함되지 않는다.

## 검증

- Kahlua: 25개 전체 구성품·중복 방지·실패 시 복구, 보상 전용 생성 필터 및 탄약/식량 포장 유지 PASS.
- 실제 42.21: 세 원본 모드 로딩, 25개 가방 전체 구성품·무게·반복 생성, 기존 94개 제작 제한 PASS.
- 첫 부팅에서 초기화 콜백 순서로 밀리텍 의상이 다시 등록되는 문제를 재현했다. 서버 측 후기 차단 콜백 추가 후 OnInitGlobalModData 의상 차단 PASS.
- 최종 격리 SERVER STARTED 및 저장·Shutdown handling finished 확인. 로그: logs/knights-ttaj-20261012-final-isolated.log.
- 기존 지도 마네킹 속성 오류 및 원본의 사용하지 않는 선택 품목 Base.null 모델 경고는 남아 있다. 검사한 세트 생성에서는 오류를 관측하지 않았다.
- Windows PowerShell 5.1: 서명 설치, 실패 시 복구, 동일 버전 재실행, 기존 별도 모드 보존 PASS.
- 운영 적용·공개 배포: 0.1.0-20261012.4로 진행. 최종 상태는 아래 기록 참조.

운영 적용 완료: 0.1.0-20261012.4, 자체 모드 65개 파일 해시 일치. 원본 3개 Workshop 캐시 설치 및 정본 INI 102 Mod ID / 94 Workshop ID 검증. 백업: backups/owned-mods-before-0.1.0-20261012.4. 서버는 종료 상태 유지.

공개 배포 완료: GitHub 릴리스 v0.1.0-20261012.4 및 stable 채널 활성화. 실제 HTTP JSON·서명·ZIP·추출 파일 전부 검증 PASS, 운영 65개 자체 파일 일치. 증거: research/public-release-0806eed549294cc0bbdfd040a69c95cf.
