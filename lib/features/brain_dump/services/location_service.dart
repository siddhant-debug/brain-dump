import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationService {
  Future<Map<String, dynamic>?> getCurrentLocationContext() async {
    try {
      // 1. Check Permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return null;
        }
      }

      // 2. Get Position (Low accuracy is fine for city level)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5), // Short timeout to not block UI
      );

      // 3. Reverse Geocode
      String? city;
      String? country;
      String locationType = "outdoor"; // Default

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          city = place.locality ?? place.subAdministrativeArea;
          country = place.country;

          // Simple Heuristics for Location Type
          // (In a real app, this would be more sophisticated or user-tagged)
          if (place.thoroughfare != null) {
            locationType = "specific_location";
          }
        }
      } catch (e) {
        print("Geocoding failed: $e");
        // Continue with just coordinates if geocoding fails
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': city,
        'country': country,
        'location_type': locationType,
      };
    } catch (e) {
      print("Location fetch failed: $e");
      return null;
    }
  }
}
