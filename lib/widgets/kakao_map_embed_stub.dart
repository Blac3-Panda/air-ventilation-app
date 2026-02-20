import 'package:flutter/material.dart';

class KakaoMapEmbed extends StatelessWidget {
  const KakaoMapEmbed({
    super.key,
    required this.kakaoJsKey,
    required this.address,
    required this.stationName,
    this.height = 240,
  });

  final String kakaoJsKey;
  final String address;
  final String stationName;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2EAFB)),
      ),
      padding: const EdgeInsets.all(12),
      child: const Center(
        child: Text('웹이 아닌 환경에서는 카카오 지도를 외부 링크로 확인합니다.'),
      ),
    );
  }
}
