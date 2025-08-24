import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();

  String _status = "Tap on map or search to set target";
  LatLng? _targetLatLng;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _proximityTimer;

  @override
  void initState() {
    super.initState();
    _notificationService.init();
  }

  @override
  void dispose() {
    _proximityTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    setState(() {
      _targetLatLng = position;
      _status = "Target set: (${position.latitude}, ${position.longitude})";
    });
    _startProximityChecks();
  }

  Future<void> _checkProximity() async {
    if (_targetLatLng == null) {
      setState(() => _status = "Set a target first!");
      return;
    }

    final pos = await _locationService.getCurrentLocation();
    if (pos == null) {
      setState(() => _status = "Location not available");
      return;
    }

    double distance = _locationService.calculateDistance(
      pos.latitude,
      pos.longitude,
      _targetLatLng!.latitude,
      _targetLatLng!.longitude,
    );

    if (distance <= defaultThreshold) {
      await _notificationService.showNotification(
        "NearAlert",
        "You are within $defaultThreshold meters of your target!",
      );
      setState(() =>
          _status = "Near target! Distance: ${distance.toStringAsFixed(2)}m");
    } else {
      setState(() =>
          _status = "Far from target. Distance: ${distance.toStringAsFixed(2)}m");
    }
  }

  Future<void> _goToCurrentLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
      setState(() {
        _targetLatLng = LatLng(pos.latitude, pos.longitude);
        _status =
            "Current location: (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})";
      });
      _startProximityChecks();
    } else {
      setState(() => _status = "Current location not available");
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text;
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;

        bool? setDestination = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Set as Destination?"),
            content: Text(
                "Do you want to set (${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}) as your target?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("No")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Yes")),
            ],
          ),
        );

        if (setDestination ?? false) {
          _mapController.move(LatLng(loc.latitude, loc.longitude), 16);
          setState(() {
            _targetLatLng = LatLng(loc.latitude, loc.longitude);
            _status =
                "Target set: (${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)})";
          });
          _startProximityChecks();
        } else {
          _mapController.move(LatLng(loc.latitude, loc.longitude), 16);
        }

      } else {
        setState(() => _status = "Location not found");
      }
    } catch (e) {
      setState(() => _status = "Error finding location: $e");
    }
  }

  void _startProximityChecks() {
    _proximityTimer?.cancel();

    _proximityTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_targetLatLng == null) return;

      final pos = await _locationService.getCurrentLocation();
      if (pos == null) return;

      double distance = _locationService.calculateDistance(
        pos.latitude, pos.longitude,
        _targetLatLng!.latitude, _targetLatLng!.longitude,
      );

      // Determine next interval
      int intervalSec;
      if (distance > 10000) intervalSec = 180;
      else if (distance > 5000) intervalSec = 100;
      else if (distance > 2000) intervalSec = 30;
      else intervalSec = 0; // Trigger alarm

      setState(() => _status = "Distance: ${distance.toStringAsFixed(2)} m");

      if (distance <= defaultThreshold) {
        await _notificationService.showNotification(
            "NearAlert", "You are within $defaultThreshold meters!");
        // TODO: Play alarm sound
        timer.cancel();
      } else if (intervalSec > 0) {
        timer.cancel();
        _proximityTimer =
            Timer.periodic(Duration(seconds: intervalSec), (_) => _startProximityChecks());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(appName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Search location",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchLocation,
                  child: const Icon(Icons.search),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _goToCurrentLocation,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(28.6139, 77.2090),
                initialZoom: 12,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.nearalert",
                ),
                if (_targetLatLng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _targetLatLng!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_status, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _checkProximity,
                  child: const Text("Check Proximity"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
