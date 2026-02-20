
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/kakao_map_embed.dart';

const String kKakaoJsKey = String.fromEnvironment('KAKAO_JS_KEY', defaultValue: '');

void main() {
  runApp(const AirGuideApp());
}

class StatusSummary {
  const StatusSummary({
    required this.riskScore,
    required this.recommendation,
    required this.recommendedVentilationMin,
    required this.pm10Value,
    required this.pm25Value,
    required this.o3Value,
    required this.stationName,
    required this.windDirectionText,
    required this.windSpeedMs,
  });

  final int riskScore;
  final String recommendation;
  final int recommendedVentilationMin;
  final String pm10Value;
  final String pm25Value;
  final String o3Value;
  final String stationName;
  final String windDirectionText;
  final double? windSpeedMs;

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

    return StatusSummary(
      riskScore: int.tryParse('${json['riskScore']}') ?? 0,
      recommendation: '${json['recommendation'] ?? '정보 없음'}',
      recommendedVentilationMin:
          int.tryParse('${json['recommendedVentilationMin']}') ?? 0,
      pm10Value: '${air['pm10Value'] ?? '-'}',
      pm25Value: '${air['pm25Value'] ?? '-'}',
      o3Value: '${air['o3Value'] ?? '-'}',
      stationName: '${air['stationName'] ?? '측정소 정보 없음'}',
      windDirectionText: '${weather['windDirectionText'] ?? '정보 없음'}',
      windSpeedMs: weather['windSpeedMs'] is num
          ? (weather['windSpeedMs'] as num).toDouble()
          : double.tryParse('${weather['windSpeedMs']}'),
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
    final errors = <String>[];

    for (final baseUrl in baseUrls) {
      final uri = Uri.parse(
        '$baseUrl/status/summary?sidoName=${Uri.encodeQueryComponent(sidoName)}&nx=$nx&ny=$ny&address=${Uri.encodeQueryComponent(address)}',
      );

      try {
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 12));

        if (response.statusCode != 200) {
          errors.add('$baseUrl => HTTP ${response.statusCode}');
          continue;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          errors.add('$baseUrl => JSON 형식 오류');
          continue;
        }

        return StatusSummary.fromJson(decoded);
      } catch (e) {
        errors.add('$baseUrl => $e');
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
      description: '상황을 보며 짧게 환기하세요.',
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
    description: '창문을 닫고 실내 공기 관리가 필요해요.',
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

String directionLabelFromDegree(int? degree) {
  if (degree == null) return '정보 없음';
  final n = ((degree % 360) + 360) % 360;
  const labels = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
  return labels[((n + 22) ~/ 45) % 8];
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3AA7F2)),
        scaffoldBackgroundColor: const Color(0xFFF4FAFF),
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
  static const _windowDirectionKey = 'window_direction';

  int currentIndex = 1;
  bool loading = true;
  String address = '';
  int? floor;
  int? windowDirection;

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
      windowDirection = prefs.getInt(_windowDirectionKey);
      loading = false;
    });
  }

  Future<void> _save({
    required String newAddress,
    required int newFloor,
    required int newWindowDirection,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_addressKey, newAddress);
    await prefs.setInt(_floorKey, newFloor);
    await prefs.setInt(_windowDirectionKey, newWindowDirection);
    setState(() {
      address = newAddress;
      floor = newFloor;
      windowDirection = newWindowDirection;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      SetupPage(
        initialAddress: address,
        initialFloor: floor,
        initialWindowDirection: windowDirection,
        onSave: _save,
      ),
      StatusPage(address: address, floor: floor, windowDirection: windowDirection),
      const AlertPage(),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFF3FF), Color(0xFFF3FAFF), Color(0xFFFFFFFF)],
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
                        gradient: LinearGradient(colors: [Color(0xFF70C6FF), Color(0xFF2E9DEB)]),
                      ),
                      child: const Icon(Icons.air_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Air Guide',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF114A73)),
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
          NavigationDestination(icon: Icon(Icons.home_rounded), label: '설정'),
          NavigationDestination(icon: Icon(Icons.air_rounded), label: '상태'),
          NavigationDestination(icon: Icon(Icons.notifications_active_rounded), label: '알림'),
        ],
      ),
    );
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({
    super.key,
    required this.initialAddress,
    required this.initialFloor,
    required this.initialWindowDirection,
    required this.onSave,
  });

  final String initialAddress;
  final int? initialFloor;
  final int? initialWindowDirection;
  final Future<void> Function({required String newAddress, required int newFloor, required int newWindowDirection}) onSave;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _floorController;
  late final TextEditingController _windowController;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    _floorController = TextEditingController(text: widget.initialFloor?.toString() ?? '');
    _windowController = TextEditingController(text: widget.initialWindowDirection?.toString() ?? '');
  }

  @override
  void dispose() {
    _addressController.dispose();
    _floorController.dispose();
    _windowController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.onSave(
        newAddress: _addressController.text.trim(),
        newFloor: int.parse(_floorController.text.trim()),
        newWindowDirection: int.parse(_windowController.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정을 저장했습니다.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directionPresets = const [0, 45, 90, 135, 180, 225, 270, 315];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SoftCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내 집 정보 설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF124A74))),
                const SizedBox(height: 6),
                const Text('주소/층수/창문 방향을 입력하면 맞춤 환기 판단이 가능해요.'),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: '주소', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '주소를 입력하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _floorController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '층수', border: OutlineInputBorder()),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? '층수를 확인하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _windowController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '창문 방향(각도)', border: OutlineInputBorder()),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 0 || n > 360) return '0~360 사이 숫자를 입력하세요.';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in directionPresets)
                      ActionChip(
                        label: Text('$d° (${directionLabelFromDegree(d)})'),
                        onPressed: () {
                          _windowController.text = '$d';
                          setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _DirectionGuideCard(currentDegree: int.tryParse(_windowController.text.trim())),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving ? null : _submit,
                    child: Text(saving ? '저장 중...' : '설정 저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class StatusPage extends StatefulWidget {
  const StatusPage({super.key, required this.address, required this.floor, required this.windowDirection});

  final String address;
  final int? floor;
  final int? windowDirection;

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
    if (oldWidget.address != widget.address) _future = _load();
  }

  Future<StatusSummary> _load() {
    return AirGuideApi.fetchStatusSummary(
      sidoName: inferSidoNameFromAddress(widget.address),
      address: widget.address,
    );
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _openKakaoMap(String stationName) async {
    final query = widget.address.trim().isNotEmpty ? widget.address.trim() : stationName.trim();
    final uri = Uri.parse('https://map.kakao.com/link/search/${Uri.encodeComponent(query)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasSetup = widget.address.isNotEmpty && widget.floor != null && widget.windowDirection != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FutureBuilder<StatusSummary>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _SoftCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())));
            }
            if (snap.hasError) {
              return _SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('실시간 상태를 가져오지 못했어요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('${snap.error}'),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _refresh, child: const Text('다시 시도')),
                ]),
              );
            }

            final s = snap.requireData;
            final band = scoreBandFrom(s.riskScore);

            return _SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('현재 환기 상태', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF124A74))),
                  const Spacer(),
                  TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('새로고침')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: band.color,
                    child: Text('${s.riskScore}', style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('AI 스코어: ${band.label}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: band.color)),
                      Text(band.description),
                      Text('측정소: ${s.stationName}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _StatusChip(label: s.pm25Chip, icon: Icons.blur_on),
                  _StatusChip(label: '풍향 ${s.windDirectionText}', icon: Icons.explore),
                  _StatusChip(label: s.windSpeedMs == null ? '풍속 정보없음' : '풍속 ${s.windSpeedMs!.toStringAsFixed(1)}m/s', icon: Icons.air),
                ]),
                const SizedBox(height: 12),
                const _ScoreLegend(),
                const SizedBox(height: 12),
                _InfoRow(label: 'PM10', value: s.pm10Value),
                _InfoRow(label: 'PM2.5', value: s.pm25Value),
                _InfoRow(label: 'O3', value: s.o3Value),
                const SizedBox(height: 14),
                const Text('내 위치/측정소 지도', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                KakaoMapEmbed(
                  kakaoJsKey: kKakaoJsKey,
                  address: widget.address,
                  stationName: s.stationName,
                  height: 240,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => _openKakaoMap(s.stationName), icon: const Icon(Icons.map), label: const Text('카카오 지도 크게 보기')),
              ]),
            );
          },
        ),
        const SizedBox(height: 12),
        _SoftCard(
          child: hasSetup
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('내 집 기준 정보', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF124A74))),
                  const SizedBox(height: 10),
                  _InfoRow(label: '주소', value: widget.address),
                  _InfoRow(label: '층수', value: '${widget.floor}층'),
                  _InfoRow(label: '창문 방향', value: '${widget.windowDirection}° (${directionLabelFromDegree(widget.windowDirection)})'),
                  _InfoRow(label: '시도', value: inferSidoNameFromAddress(widget.address)),
                ])
              : const Text('먼저 설정 탭에서 주소/층수/창문방향을 저장해주세요.'),
        ),
      ],
    );
  }
}

class AlertPage extends StatelessWidget {
  const AlertPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(leading: Icon(Icons.warning_amber_rounded, color: Colors.orange), title: Text('창문 닫기 권고'), subtitle: Text('10:42 - 바람이 공장 방향에서 유입 중')),
        ListTile(leading: Icon(Icons.check_circle_rounded, color: Colors.green), title: Text('환기 골든타임'), subtitle: Text('09:10 - 15분 환기 권장')),
      ],
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
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6EAF9)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _DirectionGuideCard extends StatelessWidget {
  const _DirectionGuideCard({required this.currentDegree});

  final int? currentDegree;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2EAFB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('창문 방향 가이드', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('0° 북 / 90° 동 / 180° 남 / 270° 서'),
        Text('현재 입력: ${currentDegree ?? '-'}° (${directionLabelFromDegree(currentDegree)})'),
      ]),
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
      decoration: BoxDecoration(color: const Color(0xFFEAF6FF), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)]),
    );
  }
}

class _ScoreLegend extends StatelessWidget {
  const _ScoreLegend();

  @override
  Widget build(BuildContext context) {
    final items = [
      (label: '0-20 매우좋음', color: const Color(0xFF46B8FF)),
      (label: '21-40 좋음', color: const Color(0xFF22A6F2)),
      (label: '41-60 보통', color: const Color(0xFFFF9800)),
      (label: '61-80 나쁨', color: const Color(0xFFFF7043)),
      (label: '81-100 매우나쁨', color: const Color(0xFFE53935)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI 스코어 기준', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final i in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: i.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(i.label, style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}


