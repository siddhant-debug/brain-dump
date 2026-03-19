// test/features/analytics/models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_dump/features/analytics/models/analytics_models.dart';
import 'package:brain_dump/features/analytics/models/pipeline_models.dart';

void main() {
  group('Analytics Models', () {
    test('ConsistencyData.fromJson parses correctly', () {
      /// 52: ConsistencyData.fromJson parses correctly
      final json = {
        'current_streak': 5,
        'longest_streak': 10,
        'total_notes': 100,
        'active_days_last_30': 15,
        'heatmap': [
          {'date': '2024-03-01', 'count': 2},
          {'date': '2024-03-02', 'count': 0},
        ],
      };

      final data = ConsistencyData.fromJson(json);

      expect(data.currentStreak, 5);
      expect(data.longestStreak, 10);
      expect(data.heatmap.length, 2);
      expect(data.heatmap[0].count, 2);
    });

    test('ThemesData.fromJson parses correctly', () {
      /// 53: ThemesData.fromJson parses correctly
      final json = {
        'window_days': 30,
        'total_notes_analyzed': 50,
        'themes': [
          {
            'key': 'work',
            'name': 'Work',
            'count': 20,
            'pct': 40.0,
            'sample': 'Meeting about project X'
          }
        ],
      };

      final data = ThemesData.fromJson(json);

      expect(data.windowDays, 30);
      expect(data.themes.length, 1);
      expect(data.themes[0].name, 'Work');
    });

    test('LoopsData.fromJson parses correctly', () {
      /// 54: LoopsData.fromJson parses correctly
      final json = {
        'notes_scanned': 200,
        'loops': [
          {
            'theme_guess': 'Anxiety about deadline',
            'occurrences': 3,
            'severity': 'high',
            'first_seen': '2024-02-01',
            'last_seen': '2024-02-15',
            'notes': [
              {'date': '2024-02-01', 'preview': 'Deadline is close'}
            ],
            'path_forward': 'Break tasks down'
          }
        ],
      };

      final data = LoopsData.fromJson(json);

      expect(data.notesScanned, 200);
      expect(data.loops.length, 1);
      expect(data.loops[0].severity, 'high');
      expect(data.loops[0].notes.length, 1);
    });

    test('PipelineData.fromJson parses correctly', () {
      /// 55: PipelineData.fromJson parses correctly
      final json = {
        'generated_at': '2024-03-19T10:00:00Z',
        'lanes': [
          {'key': 'work', 'label': 'Work', 'color': '#2979FF'}
        ],
        'nodes': [
          {
            'id': '1',
            'content': 'Finish testing',
            'topic': 'Coding',
            'lane': 0,
            'thought_type': 'action',
            'timestamp': '2024-03-19T09:00:00Z',
            'parent_ids': []
          }
        ],
      };

      final data = PipelineData.fromJson(json);

      expect(data.lanes.length, 1);
      expect(data.nodes.length, 1);
      expect(data.nodes[0].thoughtType, ThoughtType.action);
    });
  });
}
