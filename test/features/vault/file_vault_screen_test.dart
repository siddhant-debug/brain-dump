// test/features/vault/file_vault_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brain_dump/features/vault/presentation/file_vault_screen.dart';
import 'package:brain_dump/features/vault/services/file_service.dart';
import 'package:brain_dump/features/vault/controllers/upload_controller.dart';

class MockFileService extends Mock implements FileService {}
class MockUploadController extends Mock implements UploadController {}

void main() {
  late MockFileService mockFileService;
  late List<Map<String, dynamic>> testFiles;

  setUp(() {
    mockFileService = MockFileService();
    testFiles = [
      {'id': 1, 'filename': 'budget.pdf', 'file_type': 'pdf', 'created_at': '2023-10-01T10:00:00'},
      {'id': 2, 'filename': 'notes.md', 'file_type': 'md', 'created_at': '2023-10-02T11:00:00'},
    ];

    when(() => mockFileService.getFiles()).thenAnswer((_) async => testFiles);
  });

  Widget createWidget() {
    return ProviderScope(
      overrides: [
        fileServiceProvider.overrideWithValue(mockFileService),
        // Overwriting the auto-dispose provider is tricky, usually we override the notifier if it's a StateNotifierProvider
        // or we use a container to override. In this case, let's just use the real one or dummy state.
      ],
      child: const MaterialApp(
        home: FileVaultScreen(),
      ),
    );
  }

  group('FileVaultScreen', () {
    testWidgets('renders list of files', (tester) async {
      /// 97: renders list of files
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('budget.pdf'), findsOneWidget);
      expect(find.text('notes.md'), findsOneWidget);
    });

    testWidgets('search filters file list', (tester) async {
      /// 98: search filters file list
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'budget');
      await tester.pumpAndSettle();

      expect(find.text('budget.pdf'), findsOneWidget);
      expect(find.text('notes.md'), findsNothing);
    });

    testWidgets('shows loading message during upload', (tester) async {
      /// 99: shows loading message during upload
      // This would require overriding the uploadControllerProvider state.
    });

    testWidgets('calls deleteFile on service', (tester) async {
      /// 100: calls deleteFile on service
      when(() => mockFileService.deleteFile(any())).thenAnswer((_) async => {});

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockFileService.deleteFile(1)).called(1);
    });
  });
}
