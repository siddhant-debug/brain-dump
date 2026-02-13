import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
