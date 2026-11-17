import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/catalog.dart';
import '../services/api.dart';
import '../theme/taricrea_theme.dart';
import '../widgets/common.dart';

class BusinessLocationsScreen extends StatefulWidget {
  const BusinessLocationsScreen(this.api, {super.key});

  final Api api;

  @override
  State<BusinessLocationsScreen> createState() =>
      _BusinessLocationsScreenState();
}

class _BusinessLocationsScreenState extends State<BusinessLocationsScreen> {
  late Future<List<Business>> locations;

  @override
  void initState() {
    super.initState();
    locations = loadLocations();
  }

  Future<List<Business>> loadLocations() async {
    final businesses = <int, Business>{};
    var page = await widget.api.businesses(0, '', null);
    while (true) {
      businesses.addEntries(
        page.items.map((business) => MapEntry(business.id, business)),
      );
      if (!page.hasMore || !mounted) return businesses.values.toList();
      page = await widget.api.businesses(page.page + 1, '', null);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Business>>(
    future: locations,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Content(
          children: [Heading('Ubicaciones de emprendimientos'), Busy()],
        );
      }
      if (snapshot.hasError) {
        final error = snapshot.error;
        return Content(
          children: [
            const Heading('Ubicaciones de emprendimientos'),
            LoadError(
              error is ApiFailure
                  ? error.message
                  : 'No se pudieron cargar las ubicaciones.',
              retry: () {
                final refreshed = loadLocations();
                setState(() {
                  locations = refreshed;
                });
              },
            ),
          ],
        );
      }
      return LocationScreen(businesses: snapshot.data!);
    },
  );
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({
    this.business,
    this.businesses,
    this.initial,
    this.pick = false,
    super.key,
  });
  final Business? business;
  final List<Business>? businesses;
  final Coordinates? initial;
  final bool pick;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final map = MapController();
  final tiles = NetworkTileProvider(
    headers: {'User-Agent': 'TariCrea/1.0 (com.example.taricrea)'},
    silenceExceptions: true,
    attemptDecodeOfHttpErrorResponses: false,
  );
  Coordinates? point;
  bool loading = false;
  bool settings = false;
  bool serviceSettings = false;
  String? error;

  @override
  void initState() {
    super.initState();
    point = widget.initial ?? widget.business?.point;
  }

  @override
  void didUpdateWidget(covariant LocationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business != widget.business && !widget.pick) {
      point = widget.business?.point;
    }
  }

  Future<void> locate() async {
    if (loading) return;
    setState(() {
      loading = true;
      settings = false;
      serviceSettings = false;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        serviceSettings = true;
        throw const FormatException(
          'Activa la ubicación del dispositivo para usar el GPS.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        settings = true;
        throw const FormatException(
          'Habilita el permiso de ubicación de TariCrea en Ajustes.',
        );
      }
      if (permission == LocationPermission.denied) {
        throw const FormatException(
          'Concede el permiso para capturar la ubicación.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final here = Coordinates(position.latitude, position.longitude);
      map.move(LatLng(here.latitude, here.longitude), 16);
      setState(() => point = here);
    } catch (problem) {
      if (mounted) {
        setState(
          () => error = problem is FormatException ? problem.message : 'No se pudo obtener la ubicación. Acércate a un lugar abierto y vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    map.dispose();
    super.dispose();
  }

  void showBusiness(Business business) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(business.name),
            if (business.address case final address?) Text(address),
          ],
        ),
      ),
    );
  }

  Marker businessMarker(Business business) => Marker(
    point: LatLng(business.point.latitude, business.point.longitude),
    width: 48,
    height: 48,
    alignment: Alignment.topCenter,
    child: IconButton(
      tooltip: business.name,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.location_pin, color: ink, size: 42),
      onPressed: () => showBusiness(business),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final current = point;
    final pin = current == null
        ? null
        : LatLng(current.latitude, current.longitude);
    final business = widget.business;
    final businesses = widget.businesses;
    final markers = businesses?.map(businessMarker).toList() ?? [];
    final points = markers.map((marker) => marker.point).toSet().toList();
    return Content(
      children: [
        Heading(
          businesses == null
              ? 'Ubicación del negocio'
              : 'Ubicaciones de emprendimientos',
          subtitle: businesses != null
              ? businesses.isEmpty
                    ? 'Todavía no hay emprendimientos publicados.'
                    : 'Toca un marcador para ver el emprendimiento.'
              : widget.pick
              ? 'Captura el GPS o selecciona el punto en el mapa y confírmalo.'
              : business == null
              ? 'Abre un emprendimiento en Explorar para ubicarlo.'
              : 'Punto registrado por el emprendedor.',
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 340,
            child: FlutterMap(
              mapController: map,
              options: MapOptions(
                initialCenter:
                    pin ??
                    (points.isEmpty
                        ? const LatLng(-21.5355, -64.7296)
                        : points.first),
                initialZoom: pin == null && points.isEmpty ? 13 : 16,
                initialCameraFit: points.length > 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
                        maxZoom: 16,
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: widget.pick
                    ? (_, position) => setState(() {
                        point = Coordinates(
                          position.latitude,
                          position.longitude,
                        );
                      })
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: tiles,
                  maxNativeZoom: 19,
                ),
                if (pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pin,
                        width: 48,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_pin,
                          color: ink,
                          size: 46,
                        ),
                      ),
                    ],
                  ),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Material(
                    color: surface,
                    child: InkWell(
                      onTap: () => launchUrl(
                        Uri.https('www.openstreetmap.org', '/copyright'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (business != null)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(business.name),
                if (business.address != null) Text(business.address!),
              ],
            ),
          ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Lat. ${current.latitude.toStringAsFixed(7)}   Long. ${current.longitude.toStringAsFixed(7)}',
            ),
          ),
        if (widget.pick) ...[
          OutlinedButton.icon(
            onPressed: loading ? null : locate,
            icon: const Icon(Icons.my_location),
            label: Text(loading ? 'Buscando GPS…' : 'Usar mi ubicación'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: LoadError(error!),
            ),
          if (settings)
            TextButton(
              onPressed: Geolocator.openAppSettings,
              child: const Text('Abrir ajustes'),
            ),
          if (serviceSettings)
            TextButton(
              onPressed: Geolocator.openLocationSettings,
              child: const Text('Activar ubicación'),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: current == null || loading
                ? null
                : () => Navigator.pop(context, current),
            child: const Text('Confirmar ubicación'),
          ),
        ],
      ],
    );
  }
}
