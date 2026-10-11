import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/branding.dart';
import 'public_ui.dart';

/// Direct launch from the user's tap also works with web popup restrictions.
Future<void> openOfficeMaps(BuildContext context) async {
  try {
    final opened = await launchUrl(
      Uri.parse(appOfficeMapsUrl),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (opened) {
      return;
    }
  } catch (_) {
    // Retain a useful fallback if the browser or device blocks the launch.
  }
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Buka lokasi kantor'),
      content: const SelectableText(appOfficeMapsUrl),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Tutup'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await Clipboard.setData(
                const ClipboardData(text: appOfficeMapsUrl),
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tautan lokasi disalin.')),
                );
              }
            } catch (_) {
              // The selectable URL remains available if clipboard access is denied.
            }
          },
          child: const Text('Salin tautan'),
        ),
      ],
    ),
  );
}

class PublicOfficeLocation extends StatefulWidget {
  const PublicOfficeLocation({super.key});

  @override
  State<PublicOfficeLocation> createState() => _PublicOfficeLocationState();
}

class _PublicOfficeLocationState extends State<PublicOfficeLocation> {
  bool _failed = false;
  int _version = 0;

  void _tileFailed() {
    if (_failed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed) {
        setState(() => _failed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) => PublicPanel(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LOKASI KANTOR',
                style: TextStyle(
                  color: PublicUi.green,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                appInstansiUnit,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                appContactAddress,
                style: TextStyle(color: PublicUi.muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => openOfficeMaps(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Buka di Google Maps'),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          child: SizedBox(
            height: 280,
            child: _failed
                ? ColoredBox(
                    color: PublicUi.mint,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.map_outlined,
                              color: PublicUi.green,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Pratinjau peta belum dapat dimuat.',
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _failed = false;
                                _version++;
                              }),
                              child: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : FlutterMap(
                    key: ValueKey('office-map-$_version'),
                    options: const MapOptions(
                      initialCenter: LatLng(
                        appOfficeLatitude,
                        appOfficeLongitude,
                      ),
                      initialZoom: 15,
                      interactionOptions: InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.pemetaanpohon.app',
                        errorTileCallback: (_, error, stack) => _tileFailed(),
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: const LatLng(
                              appOfficeLatitude,
                              appOfficeLongitude,
                            ),
                            width: 56,
                            height: 56,
                            alignment: Alignment.topCenter,
                            child: Semantics(
                              label: 'Lokasi $appInstansiUnit',
                              button: true,
                              child: IconButton(
                                tooltip: 'Buka lokasi kantor di Google Maps',
                                onPressed: () => openOfficeMaps(context),
                                icon: const Icon(
                                  Icons.location_on_rounded,
                                  color: PublicUi.green,
                                  size: 44,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Material(
                          color: Colors.white,
                          child: TextButton(
                            onPressed: () async {
                              try {
                                await launchUrl(
                                  Uri.parse(
                                    'https://www.openstreetmap.org/copyright',
                                  ),
                                  webOnlyWindowName: '_blank',
                                );
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Buka openstreetmap.org/copyright untuk atribusi peta.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}