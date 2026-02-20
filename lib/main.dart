import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/daum_postcode.dart';
import 'widgets/kakao_map_embed.dart';

const String kKakaoJsKey = String.fromEnvironment(
  'KAKAO_JS_KEY',
  defaultValue: '',
);
const Color kPrimaryColor = Color(0xFF2F80ED);
const Color kSecondaryColor = Color(0xFF27AE60);
const Color kAccentColor = Color(0xFFB2F5EA);

void main() {
  runApp(const AirGuideApp());
}

class StatusSummary {
  const StatusSummary({
    required this.riskScore,
    required this.scoreGrade,
    required this.integratedIndex,
    required this.integratedIndexGrade,
    required this.dominantPollutant,
    required this.recommendation,
    required this.recommendedVentilationMin,
    required this.pm10Value,
    required this.pm25Value,
    required this.o3Value,
    required this.no2Value,
    required this.so2Value,
    required this.coValue,
    required this.stationName,
    required this.windDirectionText,
    required this.windSpeedMs,
    required this.reasons,
    required this.notificationMessage,
  });

  final int riskScore;
  final String scoreGrade;
  final int integratedIndex;
  final String integratedIndexGrade;
  final String dominantPollutant;
  final String recommendation;
  final int recommendedVentilationMin;

  final String pm10Value;
  final String pm25Value;
  final String o3Value;
  final String no2Value;
  final String so2Value;
  final String coValue;

  final String stationName;
  final String windDirectionText;
  final double? windSpeedMs;
  final List<String> reasons;
  final String notificationMessage;

  String get pm25Chip {
    final pm = double.tryParse(pm25Value);
    if (pm == null) return 'PM2.5 정보없음';
    if (pm <= 15) return 'PM2.5 좋음';
    if (pm <= 35) return 'PM2.5 보통';
    if (pm <= 75) return 'PM2.5 나쁨';
    return 'PM2.5 매우나쁨';
  }

  static StatusSummary fromJson(Map<String, dynamic> json) {
    final air = (json['air'] is Map<String, dynamic>)
        ? json['air'] as Map<String, dynamic>
        : <String, dynamic>{};
    final weather = (json['weather'] is Map<String, dynamic>)
        ? json['weather'] as Map<String, dynamic>
        : <String, dynamic>{};

    final reasonsRaw = json['reasons'];
    final parsedReasons = (reasonsRaw is List)
        ? reasonsRaw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList()
        : <String>[];

    return StatusSummary(
      riskScore: int.tryParse('${json['riskScore']}') ?? 0,
      scoreGrade: '${json['scoreGrade'] ?? '정보없음'}',
      integratedIndex: int.tryParse('${json['integratedIndex']}') ?? 0,
      integratedIndexGrade: '${json['integratedIndexGrade'] ?? '정보없음'}',
      dominantPollutant: '${json['dominantPollutant'] ?? '-'}',
      recommendation: '${json['recommendation'] ?? '정보 없음'}',
      recommendedVentilationMin:
          int.tryParse('${json['recommendedVentilationMin']}') ?? 0,
      pm10Value: '${air['pm10Value'] ?? '-'}',
      pm25Value: '${air['pm25Value'] ?? '-'}',
      o3Value: '${air['o3Value'] ?? '-'}',
      no2Value: '${air['no2Value'] ?? '-'}',
      so2Value: '${air['so2Value'] ?? '-'}',
      coValue: '${air['coValue'] ?? '-'}',
      stationName: '${air['stationName'] ?? '측정소 정보 없음'}',
      windDirectionText: '${weather['windDirectionText'] ?? '정보 없음'}',
      windSpeedMs: weather['windSpeedMs'] is num
          ? (weather['windSpeedMs'] as num).toDouble()
          : double.tryParse('${weather['windSpeedMs']}'),
      reasons: parsedReasons,
      notificationMessage: '${json['notificationMessage'] ?? ''}',
    );
  }
}

class ForecastItem {
  const ForecastItem({
    required this.fcstDate,
    required this.fcstTime,
    required this.temperatureC,
    required this.popPct,
    required this.sky,
    required this.pty,
    required this.windSpeedMs,
    required this.windDirectionText,
  });

  final String fcstDate;
  final String fcstTime;
  final double? temperatureC;
  final double? popPct;
  final String sky;
  final String pty;
  final double? windSpeedMs;
  final String windDirectionText;

  String get label {
    if (fcstDate.length < 8 || fcstTime.length < 4) {
      return '$fcstDate $fcstTime';
    }
    final mm = fcstDate.substring(4, 6);
    final dd = fcstDate.substring(6, 8);
    final hh = fcstTime.substring(0, 2);
    return '$mm/$dd $hh:00';
  }

  static ForecastItem fromJson(Map<String, dynamic> json) {
    return ForecastItem(
      fcstDate: '${json['fcstDate'] ?? ''}',
      fcstTime: '${json['fcstTime'] ?? ''}',
      temperatureC: json['temperatureC'] is num
          ? (json['temperatureC'] as num).toDouble()
          : double.tryParse('${json['temperatureC']}'),
      popPct: json['popPct'] is num
          ? (json['popPct'] as num).toDouble()
          : double.tryParse('${json['popPct']}'),
      sky: '${json['sky'] ?? '정보없음'}',
      pty: '${json['pty'] ?? '정보없음'}',
      windSpeedMs: json['windSpeedMs'] is num
          ? (json['windSpeedMs'] as num).toDouble()
          : double.tryParse('${json['windSpeedMs']}'),
      windDirectionText: '${json['windDirectionText'] ?? '정보없음'}',
    );
  }
}

class WeatherSummary {
  const WeatherSummary({
    required this.temperatureC,
    required this.humidityPct,
    required this.rainfallMm,
    required this.windSpeedMs,
    required this.windDirectionText,
    required this.baseDate,
    required this.baseTime,
    required this.forecast,
  });

  final double? temperatureC;
  final double? humidityPct;
  final double? rainfallMm;
  final double? windSpeedMs;
  final String windDirectionText;
  final String baseDate;
  final String baseTime;
  final List<ForecastItem> forecast;

  static WeatherSummary fromJson(Map<String, dynamic> json) {
    final current = (json['current'] is Map<String, dynamic>)
        ? json['current'] as Map<String, dynamic>
        : <String, dynamic>{};

    final list = (json['forecast'] is List)
        ? (json['forecast'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ForecastItem.fromJson)
              .toList()
        : <ForecastItem>[];

    return WeatherSummary(
      temperatureC: current['temperatureC'] is num
          ? (current['temperatureC'] as num).toDouble()
          : double.tryParse('${current['temperatureC']}'),
      humidityPct: current['humidityPct'] is num
          ? (current['humidityPct'] as num).toDouble()
          : double.tryParse('${current['humidityPct']}'),
      rainfallMm: current['rainfallMm'] is num
          ? (current['rainfallMm'] as num).toDouble()
          : double.tryParse('${current['rainfallMm']}'),
      windSpeedMs: current['windSpeedMs'] is num
          ? (current['windSpeedMs'] as num).toDouble()
          : double.tryParse('${current['windSpeedMs']}'),
      windDirectionText: '${current['windDirectionText'] ?? '정보없음'}',
      baseDate: '${json['baseDate'] ?? ''}',
      baseTime: '${json['baseTime'] ?? ''}',
      forecast: list,
    );
  }
}

class AirGuideApi {
  static List<String> get baseUrls => kIsWeb
      ? const ['http://localhost:8000', 'http://127.0.0.1:8000']
      : const ['http://10.0.2.2:8000', 'http://127.0.0.1:8000'];

  static Future<StatusSummary> fetchStatusSummary({
    required String sidoName,
    required String address,
    int nx = 60,
    int ny = 127,
  }) async {
    final uri = await _firstReachableUri(
      (base) => Uri.parse(
        '$base/status/summary?sidoName=${Uri.encodeQueryComponent(sidoName)}&nx=$nx&ny=$ny&address=${Uri.encodeQueryComponent(address)}',
      ),
    );

    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('상태 조회 실패: HTTP ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('상태 응답 형식 오류');
    }

    return StatusSummary.fromJson(decoded);
  }

  static Future<WeatherSummary> fetchWeatherSummary({
    required String address,
    int nx = 60,
    int ny = 127,
  }) async {
    final uri = await _firstReachableUri(
      (base) => Uri.parse(
        '$base/weather/summary?nx=$nx&ny=$ny&address=${Uri.encodeQueryComponent(address)}',
      ),
    );

    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('날씨 조회 실패: HTTP ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('날씨 응답 형식 오류');
    }

    return WeatherSummary.fromJson(decoded);
  }

  static Future<Uri> _firstReachableUri(
    Uri Function(String baseUrl) builder,
  ) async {
    final errors = <String>[];

    for (final base in baseUrls) {
      final uri = builder(base);
      try {
        final res = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) return uri;
        errors.add('$base => ${res.statusCode}');
      } catch (e) {
        errors.add('$base => $e');
      }
    }

    throw Exception('백엔드 연결 실패: ${errors.join(' | ')}');
  }
}

class ScoreBand {
  const ScoreBand({
    required this.label,
    required this.color,
    required this.description,
  });

  final String label;
  final Color color;
  final String description;
}

ScoreBand scoreBandFrom(int score) {
  final s = score.clamp(0, 100);
  if (s <= 20) {
    return const ScoreBand(
      label: '매우좋음',
      color: Color(0xFF46B8FF),
      description: '환기하기 가장 좋은 상태예요.',
    );
  }
  if (s <= 40) {
    return const ScoreBand(
      label: '좋음',
      color: Color(0xFF22A6F2),
      description: '짧게 환기하면 쾌적해요.',
    );
  }
  if (s <= 60) {
    return const ScoreBand(
      label: '보통',
      color: Color(0xFFFF9800),
      description: '대기 상황을 보며 잠깐 환기하세요.',
    );
  }
  if (s <= 80) {
    return const ScoreBand(
      label: '나쁨',
      color: Color(0xFFFF7043),
      description: '가급적 환기를 줄이는 게 좋아요.',
    );
  }
  return const ScoreBand(
    label: '매우나쁨',
    color: Color(0xFFE53935),
    description: '창문을 닫고 실내 공기 관리를 권장해요.',
  );
}

String inferSidoNameFromAddress(String address) {
  final normalized = address.trim().replaceAll(' ', '');
  if (normalized.isEmpty) return '서울';

  const aliases = <String, String>{
    '서울특별시': '서울',
    '서울시': '서울',
    '서울': '서울',
    '부산광역시': '부산',
    '부산시': '부산',
    '부산': '부산',
    '대구광역시': '대구',
    '대구시': '대구',
    '대구': '대구',
    '인천광역시': '인천',
    '인천시': '인천',
    '인천': '인천',
    '광주광역시': '광주',
    '광주시': '광주',
    '광주': '광주',
    '대전광역시': '대전',
    '대전시': '대전',
    '대전': '대전',
    '울산광역시': '울산',
    '울산시': '울산',
    '울산': '울산',
    '세종특별자치시': '세종',
    '세종시': '세종',
    '세종': '세종',
    '경기도': '경기',
    '경기': '경기',
    '강원특별자치도': '강원',
    '강원도': '강원',
    '강원': '강원',
    '충청북도': '충북',
    '충북': '충북',
    '충청남도': '충남',
    '충남': '충남',
    '전북특별자치도': '전북',
    '전라북도': '전북',
    '전북': '전북',
    '전라남도': '전남',
    '전남': '전남',
    '경상북도': '경북',
    '경북': '경북',
    '경상남도': '경남',
    '경남': '경남',
    '제주특별자치도': '제주',
    '제주도': '제주',
    '제주': '제주',
  };

  for (final e in aliases.entries) {
    if (normalized.contains(e.key)) return e.value;
  }
  return '서울';
}

String ventilationTipByWind({
  required String recommendation,
  required String windText,
}) {
  if (recommendation == '창문 닫기') {
    return '현재는 창문을 닫고 실내 공기 관리가 좋아요.';
  }

  if (windText.contains('북')) return '남쪽 창문 중심으로 5~10분 환기해보세요.';
  if (windText.contains('남')) return '북쪽 창문 중심으로 5~10분 환기해보세요.';
  if (windText.contains('동')) return '서쪽 창문 중심으로 5~10분 환기해보세요.';
  if (windText.contains('서')) return '동쪽 창문 중심으로 5~10분 환기해보세요.';

  return '바람 반대쪽 창문부터 짧게 열어 교차 환기하세요.';
}

String formatForecastDate(String yyyymmdd) {
  if (yyyymmdd.length != 8) return yyyymmdd;
  final mm = yyyymmdd.substring(4, 6);
  final dd = yyyymmdd.substring(6, 8);
  return '$mm/$dd';
}

String formatForecastHour(String hhmm) {
  if (hhmm.length < 2) return hhmm;
  final hh = int.tryParse(hhmm.substring(0, 2)) ?? 0;
  final ampm = hh < 12 ? '오전' : '오후';
  final h12 = hh % 12 == 0 ? 12 : hh % 12;
  return '$ampm ${h12.toString()}시';
}

IconData forecastIconFor(ForecastItem item) {
  if (item.pty.contains('비') || item.pty.contains('소나기')) {
    return Icons.umbrella_rounded;
  }
  if (item.pty.contains('눈')) return Icons.ac_unit_rounded;
  if (item.sky.contains('맑음')) return Icons.wb_sunny_rounded;
  if (item.sky.contains('흐림')) return Icons.cloud_rounded;
  if (item.sky.contains('구름')) return Icons.cloud_queue_rounded;
  return Icons.wb_cloudy_rounded;
}

Map<String, double?> minMaxTemp(List<ForecastItem> items) {
  final temps = items.map((e) => e.temperatureC).whereType<double>().toList();
  if (temps.isEmpty) return {'min': null, 'max': null};
  temps.sort();
  return {'min': temps.first, 'max': temps.last};
}

class AirGuideApp extends StatelessWidget {
  const AirGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Air Guide',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKrTextTheme(),
        colorScheme: const ColorScheme.light(
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
          tertiary: kAccentColor,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5FAFF),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _addressKey = 'address';
  static const _floorKey = 'floor';
  static const _notifyGoodKey = 'notify_good';
  static const _notifyBadKey = 'notify_bad';
  static const _notifyTrafficKey = 'notify_traffic';

  int currentIndex = 0;
  bool loading = true;

  String address = '';
  int? floor;
  bool notifyGood = true;
  bool notifyBad = true;
  bool notifyTraffic = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      address = prefs.getString(_addressKey) ?? '';
      floor = prefs.getInt(_floorKey);
      notifyGood = prefs.getBool(_notifyGoodKey) ?? true;
      notifyBad = prefs.getBool(_notifyBadKey) ?? true;
      notifyTraffic = prefs.getBool(_notifyTrafficKey) ?? true;
      loading = false;
    });
  }

  Future<void> _saveSettings({
    required String newAddress,
    required int newFloor,
    required bool newNotifyGood,
    required bool newNotifyBad,
    required bool newNotifyTraffic,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_addressKey, newAddress);
    await prefs.setInt(_floorKey, newFloor);
    await prefs.setBool(_notifyGoodKey, newNotifyGood);
    await prefs.setBool(_notifyBadKey, newNotifyBad);
    await prefs.setBool(_notifyTrafficKey, newNotifyTraffic);

    setState(() {
      address = newAddress;
      floor = newFloor;
      notifyGood = newNotifyGood;
      notifyBad = newNotifyBad;
      notifyTraffic = newNotifyTraffic;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      StatusPage(address: address, floor: floor),
      WeatherPage(address: address, floor: floor),
      SettingsPage(
        initialAddress: address,
        initialFloor: floor,
        initialNotifyGood: notifyGood,
        initialNotifyBad: notifyBad,
        initialNotifyTraffic: notifyTraffic,
        onSave: _saveSettings,
      ),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF4FF), Color(0xFFF5FCFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF70C6FF), Color(0xFF2E9DEB)],
                        ),
                      ),
                      child: const Icon(Icons.air_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Air Guide',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF114A73),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: pages[currentIndex]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (v) => setState(() => currentIndex = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.air_rounded), label: '상태'),
          NavigationDestination(icon: Icon(Icons.cloud_outlined), label: '날씨'),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialAddress,
    required this.initialFloor,
    required this.initialNotifyGood,
    required this.initialNotifyBad,
    required this.initialNotifyTraffic,
    required this.onSave,
  });

  final String initialAddress;
  final int? initialFloor;
  final bool initialNotifyGood;
  final bool initialNotifyBad;
  final bool initialNotifyTraffic;
  final Future<void> Function({
    required String newAddress,
    required int newFloor,
    required bool newNotifyGood,
    required bool newNotifyBad,
    required bool newNotifyTraffic,
  })
  onSave;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _basicFormKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _floorController;

  late bool _notifyGood;
  late bool _notifyBad;
  late bool _notifyTraffic;
  String _languageCode = 'ko';

  bool saving = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    _floorController = TextEditingController(
      text: widget.initialFloor?.toString() ?? '',
    );
    _notifyGood = widget.initialNotifyGood;
    _notifyBad = widget.initialNotifyBad;
    _notifyTraffic = widget.initialNotifyTraffic;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final selected = await DaumPostcode.pickAddress();
    if (!mounted) return;

    if (selected == null || selected.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소를 불러오지 못했어요. 직접 입력도 가능합니다.')),
      );
      return;
    }

    _addressController.text = selected.trim();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_basicFormKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.onSave(
        newAddress: _addressController.text.trim(),
        newFloor: int.parse(_floorController.text.trim()),
        newNotifyGood: _notifyGood,
        newNotifyBad: _notifyBad,
        newNotifyTraffic: _notifyTraffic,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정을 저장했습니다.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openCategory({required String title, required Widget child}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _SettingsCategoryPage(title: title, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF7FF),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '설정',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F4E8C),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsMenuTile(
                      icon: Icons.tune_rounded,
                      title: '기본설정',
                      subtitle: '주소/층수',
                      onTap: () => _openCategory(
                        title: '기본설정',
                        child: Form(
                          key: _basicFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: '주소',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? '주소를 입력하세요.'
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _pickAddress,
                                  icon: const Icon(Icons.search),
                                  label: const Text('주소 찾기'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _floorController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '층수',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    (int.tryParse(v ?? '') ?? 0) <= 0
                                    ? '층수를 확인하세요.'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: saving ? null : _submit,
                                  child: Text(saving ? '저장 중...' : '저장'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _SettingsMenuTile(
                      icon: Icons.notifications_active_rounded,
                      title: '알림',
                      subtitle: '알림 카테고리',
                      onTap: () => _openCategory(
                        title: '알림',
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('환기 권장 알림 (좋음 이상)'),
                              value: _notifyGood,
                              onChanged: (v) => setState(() => _notifyGood = v),
                            ),
                            SwitchListTile(
                              title: const Text('대기 주의 알림 (보통 이하)'),
                              value: _notifyBad,
                              onChanged: (v) => setState(() => _notifyBad = v),
                            ),
                            SwitchListTile(
                              title: const Text('도로/오염원 경고 알림'),
                              value: _notifyTraffic,
                              onChanged: (v) =>
                                  setState(() => _notifyTraffic = v),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: saving ? null : _submit,
                                child: Text(saving ? '저장 중...' : '저장'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _SettingsMenuTile(
                      icon: Icons.language_rounded,
                      title: '언어',
                      subtitle: '앱 언어',
                      onTap: () => _openCategory(
                        title: '언어',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment<String>(
                                  value: 'ko',
                                  label: Text('한국어'),
                                ),
                                ButtonSegment<String>(
                                  value: 'en',
                                  label: Text('English'),
                                ),
                              ],
                              selected: {_languageCode},
                              onSelectionChanged: (value) {
                                setState(() => _languageCode = value.first);
                              },
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '한국어 중심 UI',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _SettingsMenuTile(
                      icon: Icons.info_outline_rounded,
                      title: '앱정보',
                      subtitle: '버전 및 안내',
                      onTap: () => _openCategory(
                        title: '앱정보',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Air Guide',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text('Version 1.0.0'),
                            SizedBox(height: 10),
                            Text('실시간 공공데이터 기반 환기 안내 앱입니다.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8EBFF)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE8F2FF),
                child: Icon(icon, color: kPrimaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF6C8DB0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCategoryPage extends StatelessWidget {
  const _SettingsCategoryPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1F4E8C),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _SoftCard(child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusPage extends StatefulWidget {
  const StatusPage({super.key, required this.address, required this.floor});

  final String address;
  final int? floor;

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  late Future<StatusSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant StatusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address ||
        oldWidget.floor != widget.floor) {
      _future = _load();
    }
  }

  Future<StatusSummary> _load() {
    if (widget.address.isEmpty || widget.floor == null) {
      return Future.error('설정 탭에서 주소/층수를 먼저 저장해주세요.');
    }
    return AirGuideApi.fetchStatusSummary(
      sidoName: inferSidoNameFromAddress(widget.address),
      address: widget.address,
    );
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF4FF),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: FutureBuilder<StatusSummary>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _SoftCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            '실시간 상태를 가져오지 못했어요',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text('${snap.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _refresh,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    );
                  }

                  final s = snap.requireData;
                  final band = scoreBandFrom(s.riskScore);

                  return _SoftCard(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2F80ED), Color(0xFF1F4E8C)],
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFF2BC8FF,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                color: kAccentColor,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  s.stationName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                onPressed: _refresh,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                ),
                                tooltip: '새로고침',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 230,
                                height: 230,
                                child: CircularProgressIndicator(
                                  value:
                                      (100 - s.riskScore).clamp(0, 100) / 100,
                                  strokeWidth: 16,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    band.color,
                                  ),
                                ),
                              ),
                              Container(
                                width: 184,
                                height: 184,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF071926),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'AIR SCORE',
                                      style: TextStyle(
                                        color: Color(0xFFD4F4EE),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      s.riskScore.toString().padLeft(3, '0'),
                                      style: const TextStyle(
                                        fontSize: 44,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: band.color,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        band.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _StatusChip(
                                label: s.pm25Chip,
                                icon: Icons.blur_on,
                              ),
                              _StatusChip(
                                label: '풍향 ${s.windDirectionText}',
                                icon: Icons.explore,
                              ),
                              _StatusChip(
                                label: s.windSpeedMs == null
                                    ? '풍속 정보없음'
                                    : '풍속 ${s.windSpeedMs!.toStringAsFixed(1)}m/s',
                                icon: Icons.air,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '권고: ${s.recommendation} (${s.recommendedVentilationMin}분)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '통합지수 ${s.integratedIndex} · ${s.dominantPollutant}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key, required this.address, required this.floor});

  final String address;
  final int? floor;

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  late Future<WeatherSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant WeatherPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address ||
        oldWidget.floor != widget.floor) {
      _future = _load();
    }
  }

  Future<WeatherSummary> _load() {
    if (widget.address.isEmpty || widget.floor == null) {
      return Future.error('설정 탭에서 주소/층수를 먼저 저장해주세요.');
    }
    return AirGuideApi.fetchWeatherSummary(address: widget.address);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _openExternalMap() async {
    final query = widget.address.trim();
    if (query.isEmpty) return;
    final uri = Uri.parse(
      'https://map.kakao.com/?q=${Uri.encodeComponent(query)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지도 열기에 실패했어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF7FF),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: FutureBuilder<WeatherSummary>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _SoftCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            '날씨 정보를 가져오지 못했어요',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text('${snap.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _refresh,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    );
                  }

                  final w = snap.requireData;
                  final minMax = minMaxTemp(w.forecast);

                  final Widget mapWidget;
                  if (!kIsWeb) {
                    mapWidget = const _HintBox(
                      text: '앱 모드에서는 내장 지도가 제한될 수 있어요. 아래 버튼으로 카카오 지도를 열어주세요.',
                    );
                  } else if (kKakaoJsKey.trim().isEmpty) {
                    mapWidget = const _HintBox(
                      text: 'KAKAO_JS_KEY가 없어 내장 지도를 표시할 수 없습니다.',
                    );
                  } else {
                    mapWidget = KakaoMapEmbed(
                      kakaoJsKey: kKakaoJsKey,
                      address: widget.address,
                      stationName: widget.address,
                      height: 260,
                    );
                  }

                  return Column(
                    children: [
                      _SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 40),
                                const Expanded(
                                  child: Text(
                                    '날씨',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF124A74),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _refresh,
                                  icon: const Icon(Icons.refresh),
                                  tooltip: '새로고침',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _StatusChip(
                                  label: w.temperatureC == null
                                      ? '기온 -'
                                      : '기온 ${w.temperatureC!.toStringAsFixed(1)}°C',
                                  icon: Icons.thermostat,
                                ),
                                _StatusChip(
                                  label: w.humidityPct == null
                                      ? '습도 -'
                                      : '습도 ${w.humidityPct!.toStringAsFixed(0)}%',
                                  icon: Icons.water_drop_outlined,
                                ),
                                _StatusChip(
                                  label: w.windSpeedMs == null
                                      ? '풍속 -'
                                      : '풍속 ${w.windSpeedMs!.toStringAsFixed(1)}m/s',
                                  icon: Icons.air,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '위치 기반 날씨 지도',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF124A74),
                              ),
                            ),
                            const SizedBox(height: 8),
                            mapWidget,
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _openExternalMap,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('카카오 지도에서 열기'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              '단기예보',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF124A74),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${formatForecastDate(w.baseDate)}\n${formatForecastHour(w.baseTime)} 기준',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '최저 ${minMax['min'] == null ? '-' : '${minMax['min']!.toStringAsFixed(1)}°'} / 최고 ${minMax['max'] == null ? '-' : '${minMax['max']!.toStringAsFixed(1)}°'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            if (w.forecast.isEmpty)
                              const Text('예보 데이터 없음')
                            else
                              SizedBox(
                                height: 184,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: w.forecast.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, i) {
                                    final f = w.forecast[i];
                                    final condition =
                                        (f.pty != '없음' &&
                                            f.pty != '0' &&
                                            f.pty != '정보없음')
                                        ? f.pty
                                        : f.sky;
                                    return Container(
                                      width: 132,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFFFFA),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFCFECE4),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            formatForecastDate(f.fcstDate),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            formatForecastHour(f.fcstTime),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          Icon(
                                            forecastIconFor(f),
                                            size: 28,
                                            color: const Color(0xFF2E9DEB),
                                          ),
                                          Text(
                                            condition,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            f.temperatureC == null
                                                ? '-'
                                                : '${f.temperatureC!.toStringAsFixed(1)}°C',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            '강수확률 ${f.popPct == null ? '-' : '${f.popPct!.toStringAsFixed(0)}%'}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD8EBFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14327FBF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFFFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFECE4)),
      ),
      child: Text(text),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
    );
  }
}
