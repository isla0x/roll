# Roll

24장짜리 필름 롤을 끼우고, 다 찍으면 1~6시간(무작위) 뒤에 사진이 현상되는 레트로 카메라. Flutter.

- 필터 6종: 1998 할머니집 · 2001 수학여행 · 2009 새벽 편의점 · 2022 아빠의 시선 · 2011 첫 스마트폰 · 1996 여름방학
- 화면: 롤 끼우기 → 촬영 → 현상 중 → 현상 완료 → 앨범
- 바로 현상: 소모성 인앱 상품 `com.isla0x.roll.develop5` (롤 1개 = 1회, 5회 묶음, 한국 약 2,200원)
- 알림: 현상이 끝나는 시각에 로컬 알림 예약
- 얼굴 보정: ML Kit(폰 안)으로 얼굴을 찾아 약하게 부드럽게·밝게. 라이브 화면에도 살짝 보임. iOS 16 이상
- 서버 없음. 사진은 앱 문서 폴더(`rolls/<번호>/`)에 보관

## 시작하기

```
bash tool/setup_platforms.sh   # android/ ios/ 폴더, 권한 문구, 알림 설정, 아이콘
flutter test
flutter run
```

## 폰트

Cormorant Garamond Italic, Gowun Batang (둘 다 SIL OFL, `assets/fonts/OFL-*.txt`).

## 코드 지도

- `lib/logic/filters.dart` 필터 값과 사진 처리 (자르기, 색, 입자, 날짜 스탬프)
- `lib/logic/roll.dart`, `roll_store.dart` 롤 모델과 저장
- `lib/logic/notifier.dart`, `tickets.dart` 알림, 인앱 결제
- `lib/screens/` 화면 5개와 롤 목록
- `docs/` 지원 · 개인정보 페이지 (GitHub Pages), `docs/store-ko.md` 스토어 문구
