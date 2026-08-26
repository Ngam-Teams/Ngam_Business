import os
import re

filepath = r'C:\Project\Ngam Business\lib\features\settings\presentation\business_profile_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Add imports for map picker and latlong2
import_map = "import '../../../widgets/map_picker_screen.dart';\nimport 'package:latlong2/latlong.dart';\n"
text = text.replace("import '../data/business_service.dart';", "import '../data/business_service.dart';\n" + import_map)

# 2. Add lat/long state variables
state_vars = """
  String? _logoUrl;
  String? _coverUrl;
  double? _latitude;
  double? _longitude;
"""
text = text.replace("String? _logoUrl;\n  String? _coverUrl;", state_vars.strip())

# 3. Load profile
load_profile = """
        _logoUrl = data['business_logo_url'];
        _coverUrl = data['business_cover_url'];
        _latitude = (data['latitude'] as num?)?.toDouble();
        _longitude = (data['longitude'] as num?)?.toDouble();
"""
text = text.replace("_logoUrl = data['business_logo_url'];\n        _coverUrl = data['business_cover_url'];", load_profile.strip())

# 4. Save profile
save_profile = """
      'business_city': _cityController.text.trim(),
      'business_country': _countryController.text.trim(),
      'business_registration_number': _regNoController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
"""
text = text.replace("'business_city': _cityController.text.trim(),\n      'business_country': _countryController.text.trim(),\n      'business_registration_number': _regNoController.text.trim(),", save_profile.strip())

# 5. Add Map Picker Section
map_section = """
                        const SizedBox(height: 16),
                        _buildMapSection(),
                        
                        const SizedBox(height: 48),
"""
text = text.replace("const SizedBox(height: 48),", map_section.strip())

# 6. Add _buildMapSection widget
build_map = """
  Widget _buildMapSection() {
    final bool hasLocation = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Exact Location Pin',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: () async {
            final LatLng? initial = hasLocation ? LatLng(_latitude!, _longitude!) : null;
            final LatLng? selectedLoc = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapPickerScreen(initialLocation: initial),
              ),
            );
            if (selectedLoc != null) {
              setState(() {
                _latitude = selectedLoc.latitude;
                _longitude = selectedLoc.longitude;
              });
              // Auto-save just to be safe
              _saveProfile();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasLocation ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasLocation ? const Color(0xFF42A5F5).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMap01,
                    color: hasLocation ? const Color(0xFF42A5F5) : Colors.white54,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLocation ? 'Location Pinned' : 'Set Location Pin',
                        style: TextStyle(
                          color: hasLocation ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasLocation
                            ? '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                            : 'Required for customers to find you',
                        style: TextStyle(
                          color: hasLocation ? const Color(0xFF42A5F5) : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.white38, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
"""
text = text.replace("}\n", build_map + "\n", 1)  # replace the LAST closing brace. Actually wait, that's risky.

# Better way to insert _buildMapSection:
# find the last "}" and insert before it.
text = text[:text.rfind('}')] + build_map.replace('}\n', '') + '\n}\n'

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(text)
print("Updated business_profile_page.dart")
