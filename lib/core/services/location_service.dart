import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationFix {
  const LocationFix({required this.latitude, required this.longitude, required this.accuracyMeters});

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

class LocationException implements Exception {
  const LocationException(this.message, {this.canOpenSettings = false});

  final String message;

  /// Người dùng cần mở Cài đặt để bật GPS hoặc cấp quyền.
  final bool canOpenSettings;

  @override
  String toString() => message;
}

abstract interface class LocationService {
  /// Vị trí hiện tại. Ném [LocationException] với thông báo tiếng Việt.
  Future<LocationFix> current();

  Future<void> openSettings();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationFix> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('GPS đang tắt. Bật Vị trí trong cài đặt máy.', canOpenSettings: true);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Bạn chưa cho phép ứng dụng dùng vị trí.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Quyền vị trí đã bị chặn. Mở cài đặt ứng dụng để cho phép.',
        canOpenSettings: true,
      );
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationFix(latitude: p.latitude, longitude: p.longitude, accuracyMeters: p.accuracy);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationFix(latitude: last.latitude, longitude: last.longitude, accuracyMeters: last.accuracy);
      }
      throw const LocationException('Không lấy được GPS. Hãy chọn khu vực thủ công.');
    }
  }

  @override
  Future<void> openSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());
