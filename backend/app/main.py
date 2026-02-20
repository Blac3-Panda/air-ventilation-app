import math
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / '.env')

DATA_GO_KR_SERVICE_KEY = os.getenv('DATA_GO_KR_SERVICE_KEY', '').strip()
KAKAO_REST_API_KEY = os.getenv('KAKAO_REST_API_KEY', '').strip()

AIRKOREA_URL = 'http://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getCtprvnRltmMesureDnsty'
KMA_ULTRA_NCST_URL = 'http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst'
TMS_URL = 'http://apis.data.go.kr/B552584/cleansys/rltmMesureResult'
BUILDING_TITLE_URL = 'http://apis.data.go.kr/1613000/BldRgstHubService/getBrTitleInfo'
KAKAO_LOCAL_URL = 'https://dapi.kakao.com/v2/local/search/address.json'

KST = timezone(timedelta(hours=9))

# 대기오염 물질별 통합대기환경지수 보간 구간(근사)
POLLUTANT_BANDS: dict[str, list[tuple[float, float, int, int]]] = {
    'so2': [(0.0, 0.02, 0, 50), (0.02, 0.05, 51, 100), (0.05, 0.15, 101, 250), (0.15, 1.0, 251, 500)],
    'co': [(0.0, 2.0, 0, 50), (2.0, 9.0, 51, 100), (9.0, 15.0, 101, 250), (15.0, 50.0, 251, 500)],
    'o3': [(0.0, 0.03, 0, 50), (0.03, 0.09, 51, 100), (0.09, 0.15, 101, 250), (0.15, 0.6, 251, 500)],
    'no2': [(0.0, 0.03, 0, 50), (0.03, 0.06, 51, 100), (0.06, 0.2, 101, 250), (0.2, 2.0, 251, 500)],
    'pm10': [(0.0, 30.0, 0, 50), (30.0, 80.0, 51, 100), (80.0, 150.0, 101, 250), (150.0, 600.0, 251, 500)],
    'pm25': [(0.0, 15.0, 0, 50), (15.0, 35.0, 51, 100), (35.0, 75.0, 101, 250), (75.0, 500.0, 251, 500)],
}

POLLUTANT_LABELS = {
    'pm25': 'PM2.5',
    'pm10': 'PM10',
    'o3': 'O3',
    'no2': 'NO2',
    'so2': 'SO2',
    'co': 'CO',
}

app = FastAPI(title='Air Guide API', version='0.2.0')
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        'http://localhost:8080',
        'http://127.0.0.1:8080',
        'http://localhost:3000',
        'http://127.0.0.1:3000',
    ],
    allow_credentials=False,
    allow_methods=['*'],
    allow_headers=['*'],
)


def _require_key() -> str:
    if not DATA_GO_KR_SERVICE_KEY:
        raise HTTPException(
            status_code=500,
            detail='DATA_GO_KR_SERVICE_KEY is missing. Put it in backend/.env',
        )
    return DATA_GO_KR_SERVICE_KEY


def _request_json(url: str, params: dict[str, Any]) -> dict[str, Any]:
    try:
        res = requests.get(url, params=params, timeout=20)
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f'Upstream request failed: {exc}') from exc

    if res.status_code >= 400:
        raise HTTPException(status_code=502, detail=f'Upstream status: {res.status_code}')

    try:
        return res.json()
    except ValueError as exc:
        raise HTTPException(status_code=502, detail='Upstream returned non-JSON response') from exc


def _extract_response(data: dict[str, Any]) -> tuple[dict[str, Any], list[dict[str, Any]], dict[str, Any]]:
    response = data.get('response')
    if not isinstance(response, dict):
        raise HTTPException(status_code=502, detail='Unexpected upstream schema: missing response')

    header = response.get('header', {}) if isinstance(response.get('header'), dict) else {}
    code = str(header.get('resultCode', '00'))
    if code not in {'00', '0'}:
        msg = header.get('resultMsg', 'Unknown upstream error')
        raise HTTPException(status_code=502, detail=f'Upstream error {code}: {msg}')

    body = response.get('body', {}) if isinstance(response.get('body'), dict) else {}
    items_raw = body.get('items', [])

    if isinstance(items_raw, dict):
        items = items_raw.get('item', [])
    elif isinstance(items_raw, list):
        items = items_raw
    else:
        items = []

    if not isinstance(items, list):
        items = []

    normalized_items = [item for item in items if isinstance(item, dict)]
    return body, normalized_items, header


def _extract_items_fallback(data: dict[str, Any]) -> list[dict[str, Any]]:
    if 'response' in data and isinstance(data['response'], dict):
        _, items, _ = _extract_response(data)
        return items

    if 'items' in data and isinstance(data['items'], list):
        return [x for x in data['items'] if isinstance(x, dict)]

    return []


def _to_float(value: Any) -> float | None:
    if value in (None, '-', ''):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _latest_kma_base_time(now: datetime | None = None) -> tuple[str, str]:
    current = now.astimezone(KST) if now else datetime.now(KST)
    base = current.replace(minute=0, second=0, microsecond=0)

    if current.minute < 45:
        base -= timedelta(hours=1)

    return base.strftime('%Y%m%d'), base.strftime('%H00')


def _wind_direction_text(degree: float | None) -> str:
    if degree is None:
        return '정보 없음'
    labels = [
        '북',
        '북북동',
        '북동',
        '동북동',
        '동',
        '동남동',
        '남동',
        '남남동',
        '남',
        '남남서',
        '남서',
        '서남서',
        '서',
        '서북서',
        '북서',
        '북북서',
    ]
    idx = int((degree + 11.25) % 360 / 22.5)
    return labels[idx]


def _fetch_air_current(sido_name: str, page_no: int, num_of_rows: int) -> dict[str, Any]:
    key = _require_key()
    payload = _request_json(
        AIRKOREA_URL,
        {
            'serviceKey': key,
            'returnType': 'json',
            'numOfRows': num_of_rows,
            'pageNo': page_no,
            'sidoName': sido_name,
            'ver': '1.0',
        },
    )
    body, items, header = _extract_response(payload)

    slim_items = [
        {
            'stationName': item.get('stationName'),
            'dataTime': item.get('dataTime'),
            'pm10Value': item.get('pm10Value'),
            'pm25Value': item.get('pm25Value'),
            'o3Value': item.get('o3Value'),
            'no2Value': item.get('no2Value'),
            'so2Value': item.get('so2Value'),
            'coValue': item.get('coValue'),
            'khaiValue': item.get('khaiValue'),
            'airQualityLevel': item.get('informGrade') or item.get('khaiGrade'),
        }
        for item in items
    ]

    return {
        'source': 'airkorea:getCtprvnRltmMesureDnsty',
        'sidoName': sido_name,
        'count': len(slim_items),
        'pageNo': page_no,
        'numOfRows': num_of_rows,
        'resultCode': header.get('resultCode'),
        'resultMsg': header.get('resultMsg'),
        'items': slim_items,
        'totalCount': body.get('totalCount'),
    }


def _fetch_weather_current(nx: int, ny: int) -> dict[str, Any]:
    key = _require_key()
    base_date, base_time = _latest_kma_base_time()
    payload = _request_json(
        KMA_ULTRA_NCST_URL,
        {
            'serviceKey': key,
            'dataType': 'JSON',
            'numOfRows': 100,
            'pageNo': 1,
            'base_date': base_date,
            'base_time': base_time,
            'nx': nx,
            'ny': ny,
        },
    )
    _, items, header = _extract_response(payload)

    category_map: dict[str, Any] = {}
    for item in items:
        category = item.get('category')
        if category:
            category_map[str(category)] = item.get('obsrValue')

    wind_dir = _to_float(category_map.get('VEC'))
    wind_speed = _to_float(category_map.get('WSD'))

    return {
        'source': 'kma:getUltraSrtNcst',
        'baseDate': base_date,
        'baseTime': base_time,
        'nx': nx,
        'ny': ny,
        'resultCode': header.get('resultCode'),
        'resultMsg': header.get('resultMsg'),
        'observed': {
            'temperatureC': _to_float(category_map.get('T1H')),
            'humidityPct': _to_float(category_map.get('REH')),
            'rainfallMm': _to_float(category_map.get('RN1')),
            'windSpeedMs': wind_speed,
            'windDirectionDeg': wind_dir,
            'windDirectionText': _wind_direction_text(wind_dir),
        },
        'rawCategories': category_map,
    }


def _fetch_tms_items(page_no: int = 1, num_of_rows: int = 100) -> list[dict[str, Any]]:
    key = _require_key()
    payload = _request_json(
        TMS_URL,
        {
            'serviceKey': key,
            'pageNo': page_no,
            'numOfRows': num_of_rows,
            'type': 'json',
        },
    )
    return _extract_items_fallback(payload)


def _kakao_geocode_address(address: str | None) -> tuple[float, float] | None:
    if not address or not address.strip() or not KAKAO_REST_API_KEY:
        return None

    try:
        res = requests.get(
            KAKAO_LOCAL_URL,
            params={'query': address.strip()},
            headers={'Authorization': f'KakaoAK {KAKAO_REST_API_KEY}'},
            timeout=8,
        )
    except requests.RequestException:
        return None

    if res.status_code >= 400:
        return None

    try:
        data = res.json()
    except ValueError:
        return None

    documents = data.get('documents')
    if not isinstance(documents, list) or not documents:
        return None

    first = documents[0] if isinstance(documents[0], dict) else {}
    lat = _to_float(first.get('y'))
    lon = _to_float(first.get('x'))
    if lat is None or lon is None:
        return None
    return lat, lon


def _to_kma_grid(lat: float, lon: float) -> tuple[int, int]:
    re = 6371.00877 / 5.0
    slat1 = math.radians(30.0)
    slat2 = math.radians(60.0)
    olon = math.radians(126.0)
    olat = math.radians(38.0)
    xo = 43.0
    yo = 136.0

    sn = math.log(math.cos(slat1) / math.cos(slat2)) / math.log(
        math.tan(math.pi * 0.25 + slat2 * 0.5) / math.tan(math.pi * 0.25 + slat1 * 0.5),
    )
    sf = (math.tan(math.pi * 0.25 + slat1 * 0.5) ** sn * math.cos(slat1)) / sn
    ro = re * sf / (math.tan(math.pi * 0.25 + olat * 0.5) ** sn)
    ra = re * sf / (math.tan(math.pi * 0.25 + math.radians(lat) * 0.5) ** sn)
    theta = math.radians(lon) - olon

    if theta > math.pi:
        theta -= 2.0 * math.pi
    if theta < -math.pi:
        theta += 2.0 * math.pi

    theta *= sn
    x = int(ra * math.sin(theta) + xo + 0.5)
    y = int(ro - ra * math.cos(theta) + yo + 0.5)
    return x, y


def _extract_location_tokens(address: str) -> list[str]:
    cleaned = address.replace(',', ' ').replace('  ', ' ').strip()
    tokens = [token for token in cleaned.split(' ') if token]

    result: list[str] = []
    for token in tokens:
        if token.endswith(('시', '군', '구', '읍', '면', '동')):
            result.append(token)
            if len(token) > 1:
                result.append(token[:-1])

    seen: set[str] = set()
    deduped: list[str] = []
    for token in result:
        if token not in seen:
            seen.add(token)
            deduped.append(token)
    return deduped


def _pick_station_by_address(items: list[dict[str, Any]], address: str | None) -> dict[str, Any]:
    if not items:
        return {}

    if not address:
        return items[0]

    tokens = _extract_location_tokens(address)
    if not tokens:
        return items[0]

    for token in tokens:
        for item in items:
            station_name = str(item.get('stationName') or '')
            if token and (token in station_name or station_name in token):
                return item

    return items[0]


def _calc_sub_index(value: float | None, bands: list[tuple[float, float, int, int]]) -> float | None:
    if value is None:
        return None
    v = max(0.0, value)
    for bp_lo, bp_hi, i_lo, i_hi in bands:
        if v <= bp_hi:
            if bp_hi == bp_lo:
                return float(i_hi)
            return ((i_hi - i_lo) / (bp_hi - bp_lo)) * (v - bp_lo) + i_lo
    return float(bands[-1][3])


def _grade_from_iaqi(index_value: float) -> str:
    if index_value <= 50:
        return '좋음'
    if index_value <= 100:
        return '보통'
    if index_value <= 250:
        return '나쁨'
    return '매우나쁨'


def _score_grade_from_risk(risk: int) -> str:
    if risk <= 20:
        return '매우좋음'
    if risk <= 40:
        return '좋음'
    if risk <= 60:
        return '보통'
    if risk <= 80:
        return '나쁨'
    return '매우나쁨'


def _notification_message(score_grade: str) -> str:
    if score_grade == '매우좋음':
        return '최상의 대기 상태에요. 지금 환기하세요.'
    if score_grade == '좋음':
        return '대기 상태가 좋아요. 5~10분 환기해볼까요?'
    return '대기 상태가 좋지 않아요. 오늘은 창문을 열지 말아요.'


def _assess_tms_impact(items: list[dict[str, Any]], sido_name: str) -> tuple[int, list[str]]:
    if not items:
        return 0, []

    pollutant_pairs = [
        ('nox_mesure_value', 'nox_exhst_perm_stdr_value', 'NOx'),
        ('sox_mesure_value', 'sox_exhst_perm_stdr_value', 'SOx'),
        ('tsp_mesure_value', 'tsp_exhst_perm_stdr_value', 'TSP'),
        ('hcl_mesure_value', 'hcl_exhst_perm_stdr_value', 'HCl'),
        ('hf_mesure_value', 'hf_exhst_perm_stdr_value', 'HF'),
        ('nh3_mesure_value', 'nh3_exhst_perm_stdr_value', 'NH3'),
    ]

    max_ratio = 0.0
    max_name = ''

    for item in items:
        area_name = str(item.get('area_nm') or '')
        if sido_name and sido_name not in area_name:
            continue

        for mesure_key, stdr_key, label in pollutant_pairs:
            measured = _to_float(item.get(mesure_key))
            standard = _to_float(item.get(stdr_key))
            if measured is None or standard is None or standard <= 0:
                continue
            ratio = measured / standard
            if ratio > max_ratio:
                max_ratio = ratio
                max_name = label

    if max_ratio >= 1.0:
        return 14, [f'인근 굴뚝(TMS) 배출 {max_name}가 허용기준 대비 높아 환기 위험이 커졌어요.']
    if max_ratio >= 0.8:
        return 8, [f'인근 굴뚝(TMS) 배출 {max_name}가 허용기준에 근접해 주의가 필요해요.']
    return 0, []


def _assess_traffic_impact(traffic_level: str | None) -> tuple[int, list[str], str]:
    normalized = (traffic_level or '').strip().lower()
    source = 'input'

    if normalized not in {'low', 'normal', 'medium', 'high'}:
        hour = datetime.now(KST).hour
        normalized = 'high' if hour in {7, 8, 9, 17, 18, 19} else 'normal'
        source = 'estimated'

    if normalized == 'high':
        if source == 'estimated':
            return 7, ['출퇴근 혼잡 시간대로 추정되어 도로 배출가스 영향이 커졌어요.'], normalized
        return 10, ['도로 교통 정체로 배출가스 유입 가능성이 높아요.'], normalized

    if normalized in {'medium', 'normal'}:
        return 2, [], normalized

    return 0, [], normalized


@app.get('/health')
def health() -> dict[str, Any]:
    return {
        'ok': True,
        'hasDataGoKrKey': bool(DATA_GO_KR_SERVICE_KEY),
        'hasKakaoRestKey': bool(KAKAO_REST_API_KEY),
    }


@app.get('/air/current')
def air_current(
    sido_name: str = Query(default='서울', alias='sidoName'),
    page_no: int = Query(default=1, alias='pageNo', ge=1),
    num_of_rows: int = Query(default=10, alias='numOfRows', ge=1, le=100),
) -> dict[str, Any]:
    return _fetch_air_current(sido_name=sido_name, page_no=page_no, num_of_rows=num_of_rows)


@app.get('/weather/current')
def weather_current(
    nx: int = Query(default=60, ge=1),
    ny: int = Query(default=127, ge=1),
) -> dict[str, Any]:
    return _fetch_weather_current(nx=nx, ny=ny)


@app.get('/tms/current')
def tms_current(
    page_no: int = Query(default=1, alias='pageNo', ge=1),
    num_of_rows: int = Query(default=20, alias='numOfRows', ge=1, le=200),
) -> dict[str, Any]:
    items = _fetch_tms_items(page_no=page_no, num_of_rows=num_of_rows)
    return {
        'source': 'tms:cleansys/rltmMesureResult',
        'pageNo': page_no,
        'numOfRows': num_of_rows,
        'count': len(items),
        'items': items,
    }


@app.get('/building/title')
def building_title(
    sigungu_cd: str = Query(alias='sigunguCd', min_length=5, max_length=5),
    bjdong_cd: str = Query(alias='bjdongCd', min_length=5, max_length=5),
    bun: str = Query(default='0000', min_length=1, max_length=4),
    ji: str = Query(default='0000', min_length=1, max_length=4),
    plat_gb_cd: str = Query(default='0', alias='platGbCd', min_length=1, max_length=1),
    page_no: int = Query(default=1, alias='pageNo', ge=1),
    num_of_rows: int = Query(default=10, alias='numOfRows', ge=1, le=100),
) -> dict[str, Any]:
    key = _require_key()
    payload = _request_json(
        BUILDING_TITLE_URL,
        {
            'serviceKey': key,
            'sigunguCd': sigungu_cd,
            'bjdongCd': bjdong_cd,
            'platGbCd': plat_gb_cd,
            'bun': bun.zfill(4),
            'ji': ji.zfill(4),
            'numOfRows': num_of_rows,
            'pageNo': page_no,
            'format': 'json',
        },
    )

    body, items, header = _extract_response(payload)
    return {
        'source': 'building:BldRgstHubService/getBrTitleInfo',
        'pageNo': page_no,
        'numOfRows': num_of_rows,
        'count': len(items),
        'resultCode': header.get('resultCode'),
        'resultMsg': header.get('resultMsg'),
        'totalCount': body.get('totalCount'),
        'items': items,
    }


@app.get('/status/summary')
def status_summary(
    sido_name: str = Query(default='서울', alias='sidoName'),
    nx: int = Query(default=60, ge=1),
    ny: int = Query(default=127, ge=1),
    address: str = Query(default=''),
    traffic_level: str = Query(default='', alias='trafficLevel'),
) -> dict[str, Any]:
    used_nx = nx
    used_ny = ny
    used_geo: dict[str, Any] | None = None

    geocoded = _kakao_geocode_address(address)
    if geocoded is not None:
        lat, lon = geocoded
        used_nx, used_ny = _to_kma_grid(lat, lon)
        used_geo = {'lat': lat, 'lon': lon}

    air = _fetch_air_current(sido_name=sido_name, page_no=1, num_of_rows=100)
    weather = _fetch_weather_current(nx=used_nx, ny=used_ny)

    selected = _pick_station_by_address(air['items'], address)

    pollutant_values = {
        'pm25': _to_float(selected.get('pm25Value')),
        'pm10': _to_float(selected.get('pm10Value')),
        'o3': _to_float(selected.get('o3Value')),
        'no2': _to_float(selected.get('no2Value')),
        'so2': _to_float(selected.get('so2Value')),
        'co': _to_float(selected.get('coValue')),
    }

    sub_indices: dict[str, float] = {}
    for key, value in pollutant_values.items():
        index_value = _calc_sub_index(value, POLLUTANT_BANDS[key])
        if index_value is not None:
            sub_indices[key] = round(index_value, 1)

    dominant_pollutant = ''
    dominant_index = 0.0
    if sub_indices:
        dominant_pollutant, dominant_index = max(sub_indices.items(), key=lambda x: x[1])

    bad_count = sum(1 for x in sub_indices.values() if x >= 101)
    bonus = 75 if bad_count >= 3 else (50 if bad_count == 2 else 0)

    integrated_index = min(500, int(round(dominant_index + bonus)))
    iaqi_grade = _grade_from_iaqi(integrated_index)

    reasons: list[str] = []
    if dominant_pollutant:
        value = pollutant_values.get(dominant_pollutant)
        if value is not None and integrated_index > 50:
            reasons.append(f'{POLLUTANT_LABELS[dominant_pollutant]} 농도({value}) 영향으로 대기질 점수가 상승했어요.')

    if bad_count >= 2:
        reasons.append('나쁨 이상 오염물질이 2개 이상이라 통합점수 가산이 적용됐어요.')

    wind_speed = _to_float(weather['observed'].get('windSpeedMs'))
    wind_penalty = 0
    if wind_speed is not None and wind_speed <= 1.2:
        wind_penalty = 6
        reasons.append('풍속이 약해 오염물질이 정체될 가능성이 있어요.')
    elif wind_speed is not None and wind_speed >= 4.0:
        wind_penalty = -5

    tms_penalty = 0
    tms_reasons: list[str] = []
    try:
        tms_items = _fetch_tms_items(page_no=1, num_of_rows=100)
        tms_penalty, tms_reasons = _assess_tms_impact(tms_items, sido_name=sido_name)
    except HTTPException:
        tms_penalty, tms_reasons = 0, []

    traffic_penalty, traffic_reasons, traffic_level_used = _assess_traffic_impact(traffic_level)

    risk_score = max(0, min(100, int(round(integrated_index / 5)) + wind_penalty + tms_penalty + traffic_penalty))
    score_grade = _score_grade_from_risk(risk_score)

    reasons.extend(tms_reasons)
    reasons.extend(traffic_reasons)
    if not reasons:
        reasons.append('주요 대기오염 농도가 비교적 안정적입니다.')

    if risk_score <= 30:
        recommendation = '환기 권장'
        ventilation_min = 15
    elif risk_score <= 45:
        recommendation = '환기 권장'
        ventilation_min = 10
    elif risk_score <= 60:
        recommendation = '짧게 환기'
        ventilation_min = 5
    else:
        recommendation = '창문 닫기'
        ventilation_min = 0

    return {
        'riskScore': risk_score,
        'scoreGrade': score_grade,
        'integratedIndex': integrated_index,
        'integratedIndexGrade': iaqi_grade,
        'dominantPollutant': POLLUTANT_LABELS.get(dominant_pollutant, dominant_pollutant),
        'recommendation': recommendation,
        'recommendedVentilationMin': ventilation_min,
        'reasons': reasons,
        'notificationMessage': _notification_message(score_grade),
        'air': {
            'sidoName': air['sidoName'],
            'stationName': selected.get('stationName'),
            'selectedByAddress': bool(address),
            'dataTime': selected.get('dataTime'),
            'pm10Value': selected.get('pm10Value'),
            'pm25Value': selected.get('pm25Value'),
            'o3Value': selected.get('o3Value'),
            'no2Value': selected.get('no2Value'),
            'so2Value': selected.get('so2Value'),
            'coValue': selected.get('coValue'),
            'subIndices': sub_indices,
        },
        'weather': weather['observed'],
        'traffic': {
            'level': traffic_level_used,
            'penalty': traffic_penalty,
        },
        'tms': {
            'penalty': tms_penalty,
            'reasons': tms_reasons,
        },
        'grid': {
            'nx': used_nx,
            'ny': used_ny,
            'geocoded': bool(used_geo),
            'geo': used_geo,
        },
    }
