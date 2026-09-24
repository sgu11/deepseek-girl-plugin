# 고래 소녀 for Codex — 한국어 포크

Codex 데스크톱 창을 따라다니는 macOS 펫입니다.
이 저장소는 [tommy0103/deepseek-girl-plugin](https://github.com/tommy0103/deepseek-girl-plugin)의
`3b02c8e43225f1f65ee13447b3c5bb9d5c87874b`를 기반으로 만든 한국어 포크입니다.
[sgu11/deepseek-girl-plugin](https://github.com/sgu11/deepseek-girl-plugin)의 `main`에서
한국어 대사와 메뉴, 창 모서리 정렬, 클릭 애니메이션 중 사용량 말풍선 위치 고정을 관리합니다.

## 대사와 조작

- 작업 완료: **이 통통한 고래를 닦달한다고?** — 말풍선과 누를 때와 같은 효과음(`rubble-duck1.mp3`, 볼륨 60%)으로 알립니다.
- 기본 클릭 대사: **오늘도 고생 많았어!**, **잠깐 쉬고, 다시 힘내자!**
- 고래를 누르면 대사와 Codex 사용 한도를 약 5초 동안 표시합니다.
- 일반 말풍선을 누르면 다음 대사로 넘어갑니다. 마지막 대사 다음에는 닫힙니다.
- 고래 또는 말풍선을 잡고 끌어 위치를 바꿀 수 있습니다. 누를 때와 놓을 때 짧은 효과음이 납니다.
- 오른쪽 클릭 메뉴에서 말풍선, 대사, 가장자리 부착, 모서리 곡률, 사용 한도를 조절합니다.
  여러 대사는 `|`로 구분합니다.
- 기존 설정의 대사가 원래 중국어 기본값과 모두 일치할 때만 한국어 기본값으로 이행합니다.
  사용자 지정 대사는 보존합니다.

## 창 테두리와 모서리 부착

가장자리 부착은 투명 패널 전체가 아니라 실제 캐릭터 이미지의 알파 경계를 기준으로
계산합니다. 번들 이미지의 투명 여백도 제외하며, 왼쪽 부착 시에는 좌우를 반전합니다.
기존에 저장된 부착 방향은 유지합니다. 처음 실행할 때는 오른쪽 아래에 붙습니다.
창을 옮기거나 크기를 바꾸면 같은 가장자리와 모서리를 따라갑니다.

부착 상태에서는 창 밖으로 나오는 캐릭터 부분을 연속 곡률의 둥근 모서리로 잘라냅니다.
끌고 있는 동안과 부착이 해제된 상태에서는 이 처리를 하지 않습니다.
**모서리 곡률 조절…**에서 0~40포인트를 지정할 수 있으며 기본값은 16입니다.
0은 직각 모서리에 사용합니다. macOS의 공개 창 정보에는 Codex의 실제 모서리 곡률이
없으므로 기본값은 자동 측정값이 아닙니다. 앱 버전이나 창 상태에 맞게 조정하세요.
화면 밖에 있는 창 부분까지 펫이 따라 나가지는 않습니다.

사용량 말풍선은 캐릭터의 평상시 크기를 기준으로 위치를 유지합니다. 누르거나 놓을 때
그림이 변형되어도 말풍선은 흔들리지 않으며, 펫 자체를 옮기면 함께 이동합니다.
말풍선은 캐릭터의 모서리 마스크로 잘리지 않습니다. 긴 한국어 대사는 두 줄까지
표시하고, 화면 가장자리에서는 말풍선의 폭과 위치를 조정합니다.
캐릭터 원본 PNG를 교체하면 `WhalePanel.attachmentBounds`의 알파 경계도 다시 확인해야 합니다.

## Codex 사용 한도

로컬 Codex CLI의 App Server 읽기 전용 인터페이스로 사용 한도를 확인합니다.
남은 비율은 `100% - 사용 비율`이며, 정확한 잔여 토큰 수는 아닙니다.
주기적으로 갱신하며 오른쪽 클릭 메뉴에서 직접 새로고침할 수 있습니다.

Codex CLI에 ChatGPT 계정으로 로그인해야 합니다. API 키 방식에서는 ChatGPT 구독
한도를 제공할 수 없습니다. CLI와 데스크톱 앱의 계정이 다르면 CLI 계정의 한도를
표시합니다. 조회 실패나 오래된 정보는 이용 불가 상태로 표시합니다.

## 빌드와 로컬 설치

macOS, Xcode Command Line Tools, `python3`, 로그인된 Codex CLI가 필요합니다.
새로 설치하는 경우 포크를 내려받습니다. 해당 경로에 기존 체크아웃이 있으면
그 저장소에서 업데이트하고 빌드하세요.

```sh
git clone https://github.com/sgu11/deepseek-girl-plugin.git ~/.codex/plugins/deepseek-girl
cd ~/.codex/plugins/deepseek-girl
```

소스 체크아웃에서 실행합니다.

```sh
./scripts/build.sh
./scripts/test.sh
```

개인 마켓플레이스 `~/.agents/plugins/marketplace.json`에 아래 항목을 등록합니다.
기존 파일이 있으면 다른 항목을 보존하고 합칩니다. 경로는 이 체크아웃의 위치입니다.

```json
{
  "name": "deepseek-girl-local",
  "plugins": [{
    "name": "deepseek-girl",
    "source": {"source": "local", "path": "./.codex/plugins/deepseek-girl"},
    "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
    "category": "Productivity"
  }]
}
```

```sh
codex plugin add deepseek-girl@deepseek-girl-local
```

Codex의 `/hooks`에서 해당 플러그인의 `SessionStart`와 `Stop` 정의를 확인하고
신뢰 등록합니다. 버전별 설치 경로가 바뀌면 다시 검토가 필요할 수 있습니다.
데스크톱 앱의 새 플러그인 로딩에는 재시작이 필요할 수 있습니다.
소스 수정 후에는 다시 빌드하고 위 명령으로 설치본을 갱신한 다음 펫 프로세스를
다시 시작해야 합니다. 실행 중인 프로그램은 기존 코드를 계속 사용합니다.

## 데이터와 구현

Swift/AppKit 펫을 Python hook이 시작합니다. hook은 대화 본문이나 세션 로그를 읽지
않으며 완료 이벤트의 세션 ID, 턴 ID, 시각만 플러그인 데이터 폴더에 저장합니다.
사용량 캐시에는 조회 상태, 시각, 한도 구간, 비율, 재설정 시각이 들어갑니다.
인증 정보는 Codex CLI가 관리합니다. 위치와 사용자 설정도 플러그인 데이터 폴더에
보관합니다. 업데이트 전에 `settings.json`과 `position.json`을 보관하면 되돌릴 수 있습니다.

```sh
./bin/deepseek-girl --probe
```

위 명령은 보이는 Codex 창을 찾을 수 있는지 확인합니다. 삭제는
`codex plugin remove deepseek-girl@deepseek-girl-local`을 사용합니다.
이미 실행 중인 펫은 별도로 종료해야 합니다.
