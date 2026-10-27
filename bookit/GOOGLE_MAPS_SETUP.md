# BookIt map setup (no API key required)

BookIt uses `flutter_map`, OpenStreetMap tiles, Nominatim geocoding, and OSRM routing. This avoids Google Maps SDK keys and a Google Cloud billing account.

## Flutter dependencies

From this directory:

```bash
flutter pub get
flutter run
```

The dependencies are declared in `pubspec.yaml`. No Google Maps API key or server environment variable is needed for the route map.

## Map and routing providers

- Map tiles: OpenStreetMap. The map must keep the visible OpenStreetMap attribution.
- Place lookup: Nominatim public search endpoint.
- Driving route: OSRM public demo endpoint.

The public geocoding, tile, and routing services are shared community infrastructure, have fair-use policies, and are not guaranteed for production uptime or high request volumes. Do not send frequent/bulk geocoding requests. Before scaling BookIt to many passengers, use a provider with a production plan or host your own services. Never bulk-prefetch or download tiles from the public OpenStreetMap tile service.

## Native configuration

No Android Google Maps metadata or iOS Google Maps SDK initialization is required. Internet access remains enabled for online map tiles, geocoding, and routing.
