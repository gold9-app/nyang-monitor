# 냥모니터 (NyangMonitor)

맥 메뉴바에서 고양이가 달려요. 메모리를 많이 쓰면 빨리, 여유로우면 천천히.
고양이를 누르면 작업관리자 창이 열려요.

## 기능
- 메뉴바 고양이: 메모리(또는 CPU) 사용량에 따라 달리는 속도가 바뀜, 옆에 % 숫자
- 작업관리자 창
  - 메모리 / CPU 게이지, 메모리 상태(여유/주의/위험), 스왑
  - 앱 탭: 실행 중인 앱 (도우미 프로세스 메모리까지 합산)
  - 프로세스 탭: 내 계정 프로세스 전체
  - 찾기, 메모리순/CPU순/이름순 정렬
  - 줄에 마우스를 올리면 [종료] [강제 종료] 버튼 (강제 종료는 두 번 눌러야 실행)
- 꾸미기: 이름, 털 색 7가지, 리본/왕관/고깔모자/목도리, 달리는 기준(메모리/CPU/더 바쁜 쪽),
  메뉴바 숫자 표시, 맥 켤 때 자동 시작

## 빌드
Xcode 없이 커맨드라인 도구(swiftc)만 있으면 됨.

```
./build.sh          # build/NyangMonitor.app 생성
./build.sh install  # /Applications 에 설치하고 실행
```

주의: Aside(에이전트) 안에서 빌드한 실행파일은 맥 보안 정책이 막음 -> 터미널 앱에서 빌드할 것.

## 파일
- Sources/CatArt.swift      픽셀 고양이 그림, 액세서리, 앱 아이콘
- Sources/SystemStats.swift 메모리/CPU 측정, 달리기 속도 계산
- Sources/ProcessStore.swift 앱/프로세스 목록, 종료
- Sources/Views.swift       작업관리자 창, 꾸미기 화면
- Sources/AppDelegate.swift 메뉴바 아이콘, 애니메이션
