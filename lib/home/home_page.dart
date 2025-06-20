import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _gMapcontroller =
      Completer<GoogleMapController>();
  final defaultMapZoom = 18.0;

  final CameraPosition _kGooglePlexPos = const CameraPosition(
      target: LatLng(37.42796133580664, -122.085749655962), zoom: 18);
  Set<Marker> _markers = <Marker>{};
  LatLng? _updatedMarkerPosition;

  bool _sendingLocationToServer = false;

  void _setSendingLocationToServer(bool value) {
    if (_sendingLocationToServer == value) return;
    if (mounted) setState(() => _sendingLocationToServer = value);
  }

  @override
  void initState() {
    _fetchInitialLocation();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        mapType: MapType.satellite,
        initialCameraPosition: _kGooglePlexPos,
        onMapCreated: (GoogleMapController controller) {
          _gMapcontroller.complete(controller);
        },
        markers: _markers,
        zoomControlsEnabled: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendingLocationToServer == false && _markers.isNotEmpty
            ? _sendLocationToServer
            : null,
        label: Text(
          _sendingLocationToServer
              ? 'Uploading location...'
              : (_markers.isNotEmpty ? 'Send Location' : 'Please wait...'),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.blueAccent),
        ),
        icon: Text(_sendingLocationToServer
            ? ''
            : (_markers.isEmpty
                ? ''
                : '[${(_updatedMarkerPosition?.latitude ?? _markers.first.position.latitude).toPrecision(7)},${(_updatedMarkerPosition?.longitude ?? _markers.first.position.longitude).toPrecision(7)}]')),
      ),
    );
  }

  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied the `Future` will return an error.
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _fetchInitialLocation() async {
    final position = await _determinePosition();
    print(
        '_fetchInitialLocation : Lat Long - ${position.latitude},${position.longitude}');
    await _setMapCamera(position);
    _setMarker(position);
  }

  Future<void> _setMapCamera(Position position) async {
    final GoogleMapController controller = await _gMapcontroller.future;
    final cameraUpdate = CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: defaultMapZoom));
    await controller.animateCamera(cameraUpdate);
  }

  void _setMarker(Position position) {
    final currentMillis = DateTime.timestamp().millisecondsSinceEpoch;
    final marker = Marker(
        markerId: MarkerId(currentMillis.toString()),
        position: LatLng(position.latitude, position.longitude),
        draggable: true,
        onDragEnd: (newPos) async {
          print('NewLatLong - ${newPos.latitude},${newPos.longitude}');
          if (mounted) setState(() => _updatedMarkerPosition = newPos);
        });
    if (mounted) {
      setState(() => _markers = <Marker>{marker});
    }
  }

  Future<void> _sendLocationToServer() async {
    _setSendingLocationToServer(true);
    const url = 'https://website-d5bcbc2c.programmers.us/tableAPI.php';
    final markerLatLng = _markers.firstOrNull?.position;
    final locationCoordinate =
        '${_updatedMarkerPosition?.latitude ?? markerLatLng?.latitude ?? 0.0},${_updatedMarkerPosition?.longitude ?? markerLatLng?.longitude ?? 0.0}';
    final body = {'field1': locationCoordinate, 'field2': 'mobile'};
    print('_sendLocationToServer: Url $url , RequestBody $body');
    try {
      final response = await http.post(Uri.parse(url), body: body);
      print(
          '_sendLocationToServer: StatusCode ${response.statusCode} - Body ${response.body}');
      _setSendingLocationToServer(false);

      if (response.statusCode == 200) {
        showSnackBar(context, 'Yay! location upload success.');
      } else {
        showSnackBar(context, 'Oops! location upload failed.');
      }
    } catch (e) {
      print('_sendLocationToServer: Exception - ${e.toString()}');
      _setSendingLocationToServer(false);
      showSnackBar(context, 'Something went wrong!');
    }
  }
}

extension Ex on double {
  double toPrecision(int n) => double.parse(toStringAsFixed(n));
}

void showSnackBar(BuildContext context, String text) {
  final snackBar = SnackBar(content: Text(text));
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
