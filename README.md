# Air Guide (에어 가이드)

## 프로젝트 제목
**Air Guide - 맞춤형 환기 판단 앱**

## 한 줄 소개 (3~4줄)
Air Guide는 단순 미세먼지 조회를 넘어,  
사용자 주소/창문 방향/층수 정보를 바탕으로 “지금 환기해도 되는지”를 알려주는 앱입니다.  
대기질(에어코리아) + 기상(기상청) 데이터를 통합해 환기 위험도를 점수화하고,  
직관적인 상태 카드와 지도로 현재 상황을 빠르게 확인할 수 있습니다.

## 주요 기능
- 사용자 입력(주소, 층수, 창문 방향) 저장
- 상태 탭 기본 진입 + 하늘색/화이트 기반 UI
- Air Score(0~100) 계산 및 5단계 등급 표시  
  - 매우좋음 / 좋음 / 보통 / 나쁨 / 매우나쁨
- 대기질(PM10, PM2.5, O3), 풍향/풍속 기반 환기 권고
- 주소 기반 측정소 선택 보정(시도 추론 + 지역 토큰 매칭)
- 카카오 지도 임베드(웹) 및 지도 크게 보기 링크
- 백엔드 헬스체크(`/health`) 및 요약 API(`/status/summary`)

## 사용 기술
- Frontend
- Flutter (Dart, Material 3)
- `http`, `shared_preferences`, `google_fonts`, `url_launcher`

- Backend
- FastAPI (Python)
- `uvicorn`, `requests`, `python-dotenv`

- External APIs
- 한국환경공단 에어코리아 대기오염정보
- 기상청 초단기실황 API
- 카카오 Local REST API (주소 -> 좌표)
- 카카오 지도 JS 키 기반 웹 지도 표시

## 데이터 흐름 설명
1. 사용자가 설정 탭에서 주소/층수/창문 방향을 입력하고 저장합니다.
2. Flutter 앱이 `/status/summary?sidoName=...&address=...&nx=...&ny=...`를 호출합니다.
3. 백엔드가 주소를 카카오 Local API로 좌표 변환합니다.
4. 변환된 위경도를 기상청 격자(nx, ny)로 바꿉니다.
5. 에어코리아(대기질), 기상청(풍향/풍속) 데이터를 수집합니다.
6. 주소 토큰 기반으로 측정소를 선택하고 위험 점수를 계산합니다.
7. `riskScore`, `recommendation`, `weather`, `air`, `grid`를 프론트로 반환합니다.
8. 프론트가 등급 색상/상태 카드/지도 영역으로 사용자에게 표시합니다.

## 실행 방법
1) 저장소 클론
```bash
git clone https://github.com/Blac3-Panda/air-ventilation-app.git
cd air-ventilation-app

2) 백엔드 실행
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt

backend/.env 파일 생성:
DATA_GO_KR_SERVICE_KEY=YOUR_DATA_GO_KR_KEY
KAKAO_REST_API_KEY=YOUR_KAKAO_REST_KEY

서버 실행:
uvicorn app.main:app --reload --port 8000

헬스체크:
http://127.0.0.1:8000/health

3) 프론트 실행
프로젝트 루트에서:
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define=KAKAO_JS_KEY=YOUR_KAKAO_JS_KEY

브라우저 접속:
http://127.0.0.1:8080

## 트러블슈팅

- hasDataGoKrKey가 `false`로 나올 때  
  `backend/.env` 위치/키 값을 확인하고 백엔드 서버를 재시작합니다.

- Flutter에서 `Failed to fetch` 발생 시  
  백엔드(`127.0.0.1:8000`) 실행 여부와 CORS 허용 주소(`localhost:8080`)를 확인합니다.

- Chrome/Edge 디버그 실행 실패 시  
  `flutter run -d web-server --web-port 8080` 방식으로 실행합니다.

- GitHub push 시 non-fast-forward 에러  
  원격 변경사항을 pull 후 충돌 해결 커밋 뒤 다시 push 합니다.

## 프로젝트 회고

공공 API를 단순 조회하는 수준에서 끝내지 않고,  
주소 기반 위치 해석과 환기 판단 로직까지 연결해 실사용 가능한 형태로 발전시켰습니다.  
다음 단계에서는 측정소 거리 기반 정밀 매칭과 알림 자동화로 완성도를 높일 계획입니다.



