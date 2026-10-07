import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Membaca GPS perangkat untuk UI saja; tidak menulis data ke Firebase.
Future<LatLng> readDeviceLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception(
      'GPS belum aktif. Aktifkan layanan lokasi terlebih dahulu.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception(
      'Izin lokasi belum diberikan. Periksa pengaturan aplikasi.',
    );
  }
  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  } on TimeoutException {
    throw Exception(
      'Lokasi belum ditemukan. Coba lagi di tempat terbuka atau pilih titik pada peta.',
    );
  }
}