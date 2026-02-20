// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

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

  static final Set<String> _registered = <String>{};

  @override
  Widget build(BuildContext context) {
    if (kakaoJsKey.trim().isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD2EAFB)),
        ),
        padding: const EdgeInsets.all(12),
        child: const Center(
          child: Text('카카오 지도 표시를 위해 KAKAO_JS_KEY 설정이 필요합니다.'),
        ),
      );
    }

    final safeAddress = _escape(address.trim());
    final safeStation = _escape(stationName.trim());
    final safeKey = _escape(kakaoJsKey.trim());
    final viewType = 'kakao-map-${safeAddress.hashCode}-${safeStation.hashCode}-${safeKey.hashCode}';

    if (!_registered.contains(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final frame = html.IFrameElement()
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..srcdoc = _buildSrcDoc(
            jsKey: safeKey,
            address: safeAddress,
            stationName: safeStation,
          );
        return frame;
      });
      _registered.add(viewType);
    }

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2EAFB)),
      ),
      child: HtmlElementView(viewType: viewType),
    );
  }

  String _escape(String v) => v.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

  String _buildSrcDoc({
    required String jsKey,
    required String address,
    required String stationName,
  }) {
    return '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <style>
      html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; }
      body { overflow: hidden; }
    </style>
    <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$jsKey&autoload=false&libraries=services"></script>
  </head>
  <body>
    <div id="map"></div>
    <script>
      (function() {
        var address = '$address';
        var station = '$stationName';

        kakao.maps.load(function() {
          var map = new kakao.maps.Map(document.getElementById('map'), {
            center: new kakao.maps.LatLng(37.5665, 126.9780),
            level: 5
          });

          var geocoder = new kakao.maps.services.Geocoder();

          function placeByAddress(query, isPrimary) {
            if (!query) return;
            geocoder.addressSearch(query, function(result, status) {
              if (status === kakao.maps.services.Status.OK) {
                var lat = result[0].y;
                var lng = result[0].x;
                var pos = new kakao.maps.LatLng(lat, lng);
                if (isPrimary) {
                  map.setCenter(pos);
                }
                new kakao.maps.Marker({ map: map, position: pos });
              }
            });
          }

          placeByAddress(address, true);
          if (station && station !== address) {
            placeByAddress(station, false);
          }
        });
      })();
    </script>
  </body>
</html>
''';
  }
}

