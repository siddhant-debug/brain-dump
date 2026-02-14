import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/*
1 : DockItemModel defines the static properties of a sidebar application.
id: Unique identifier used to link with NowPlayingInfo.
icon: The visual representation in the dock.
color: The theme accent color for the item and its associated background root.
*/
class DockItemModel {
  final String id;
  final IconData icon;
  final Color color;
  final String label;

  const DockItemModel({
    required this.id,
    required this.icon,
    required this.color,
    required this.label,
  });
}

/*
2 : defaultDockItems: The registry of available system applications.
*/
const defaultDockItems = [
  DockItemModel(
    id: 'apple',
    icon: FontAwesomeIcons.apple,
    color: Colors.white,
    label: 'Apple Music',
  ),
  DockItemModel(
    id: 'spotify',
    icon: FontAwesomeIcons.spotify,
    color: Color(0xFF1DB954),
    label: 'Spotify',
  ),
  DockItemModel(
    id: 'youtube',
    icon: FontAwesomeIcons.youtube,
    color: Color(0xFFFF0000),
    label: 'YouTube',
  ),
];
