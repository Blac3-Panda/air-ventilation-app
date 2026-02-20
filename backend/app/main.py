import os
import math
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
TMS_METAL_URL = 'https://apis.data.go.kr/1480523/MetalMeasuringResultService/MetalService'
BUILDING_TITLE_URL = 'http://apis.data.go.kr/1613000/BldRgstHubService/getBrTitleInfo'
KAKAO_LOCAL_URL = 'https://dapi.kakao.com/v2/local/search/address.json'

KST = timezone(timedelta(hours=9))

app = FastAPI(title='Air Guide API', version='0.1.0')
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
    if code != '00':
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

    # 초단기실황은 보통 매시 40분 이후 안정적으로 조회 가능하므로 이전 시각 fallback.
    if current.minute < 45:
        base -= timedelta(hours=1)

    return base.strftime('%Y%m%d'), base.strftime('%H00')


def _wind_direction_text(degree: float | None) -> str:
    if degree is None:
        return '정보 없음'
    labels = ['북', '북북동', '북동', '동북동', '동', '동남동', '남동', '남남동', '남', '남남서', '남서', '서남서', '서', '서북서', '북서', '북북서']
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


def _extract_items_fallback(data: dict[str, Any]) -> list[dict[str, Any]]:
    if 'response' in data and isinstance(data['response'], dict):
        _, items, _ = _extract_response(data)
        return items

    if 'items' in data and isinstance(data['items'], list):
        return [x for x in data['items'] if isinstance(x, dict)]

    return []

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
    # 기상청 LCC DFS 변환 (위경도 -> nx, ny)
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
    key = _require_key()
    payload = _request_json(
        TMS_METAL_URL,
        {
            'serviceKey': key,
            'pageNo': page_no,
            'numOfRows': num_of_rows,
            'apiType': 'json',
        },
    )

    items = _extract_items_fallback(payload)
    return {
        'source': 'tms:MetalMeasuringResultService/MetalService',
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

    first = _pick_station_by_address(air['items'], address)
    pm25 = _to_float(first.get('pm25Value'))
    wind_speed = weather['observed'].get('windSpeedMs')

    risk = 55
    if pm25 is not None:
        if pm25 <= 15:
            risk = 20
        elif pm25 <= 35:
            risk = 45
        else:
            risk = 75

    if isinstance(wind_speed, float) and wind_speed >= 3:
        risk = max(0, risk - 5)

    if risk <= 34:
        level = '환기 권장'
        duration_min = 10
    elif risk <= 64:
        level = '짧게 환기'
        duration_min = 5
    else:
        level = '창문 닫기'
        duration_min = 0

    return {
        'riskScore': risk,
        'recommendation': level,
        'recommendedVentilationMin': duration_min,
        'air': {
            'sidoName': air['sidoName'],
            'stationName': first.get('stationName'),
            'selectedByAddress': bool(address),
            'dataTime': first.get('dataTime'),
            'pm10Value': first.get('pm10Value'),
            'pm25Value': first.get('pm25Value'),
            'o3Value': first.get('o3Value'),
        },
        'weather': weather['observed'],
        'grid': {
            'nx': used_nx,
            'ny': used_ny,
            'geocoded': bool(used_geo),
            'geo': used_geo,
        },
    }














