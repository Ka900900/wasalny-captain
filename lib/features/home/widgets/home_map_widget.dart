import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;

import 'package:waslny_captain/core/theme/app_theme.dart';

/// Full-screen OSM map widget.
///
/// When [locationGranted] is `true`, renders the interactive OSM map with
/// user-tracking enabled.  Otherwise shows a friendly location-required
/// placeholder.
class HomeMapWidget extends StatelessWidget {
  final osm.MapController mapController;
  final bool locationGranted;
  final ValueChanged<bool> onMapReady;

  const HomeMapWidget({
    super.key,
    required this.mapController,
    required this.locationGranted,
    required this.onMapReady,
  });

  @override
  Widget build(BuildContext context) {
    if (locationGranted) {
      return osm.OSMFlutter(
        controller: mapController,
        onMapIsReady: onMapReady,
        osmOption: osm.OSMOption(
          userTrackingOption: const osm.UserTrackingOption(
            enableTracking: true,
            unFollowUser: false,
          ),
          zoomOption: const osm.ZoomOption(
            initZoom: 15,
            minZoomLevel: 3,
            maxZoomLevel: 19,
          ),
        ),
      );
    }

    return Container(
      color: AppColors.bg,
      child: Center(
        child: Semantics(
          label: 'صلاحية الموقع مطلوبة',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off_rounded,
                color: AppColors.textMuted,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'صلاحية الموقع مطلوبة',
                style: AppTextStyles.bodyLarge?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى تفعيل الموقع من الإعدادات',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
