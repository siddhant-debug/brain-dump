import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/providers/dio_provider.dart';
import '../services/reminder_service.dart';
import '../services/reminder_service_interface.dart';
import '../models/reminder_parse_result.dart';
import 'smart_reminder_state.dart';

final reminderServiceProvider = Provider<ReminderServiceInterface>((ref) {
  return ReminderService();
});

final smartReminderControllerProvider =
    StateNotifierProvider<SmartReminderController, SmartReminderState>((ref) {
  final controller = SmartReminderController(
    ref.watch(reminderServiceProvider),
    ref.watch(dioProvider),
  );
  ref.onDispose(() => controller.dispose());
  return controller;
});

class SmartReminderController extends StateNotifier<SmartReminderState> with WidgetsBindingObserver {
  final ReminderServiceInterface _reminderService;
  final Dio _dio;
  final _storage = const FlutterSecureStorage();
  bool _isFetching = false;

  SmartReminderController(this._reminderService, this._dio)
      : super(SmartReminderState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Potentially re-check permissions if user returns from Settings
      _checkPermissionsSilently();
    }
  }

  Future<void> _checkPermissionsSilently() async {
    final permission = await _reminderService.checkPermissions();
    if (permission == 'authorized' && state.status == SmartReminderStatus.permissionDenied) {
      state = state.copyWith(status: SmartReminderStatus.idle);
    }
  }

  Future<void> parseInput(String text) async {
    if (_isFetching) return;
    _isFetching = true;
    
    state = state.copyWith(status: SmartReminderStatus.parsing);

    try {
      final token = await _storage.read(key: 'jwt_token');
      final timezone = DateTime.now().timeZoneName;
      final currentTime = DateTime.now().toIso8601String();

      final response = await _dio.post(
        '/api/nlp/parse-reminder',
        data: {
          'text': text,
          'timezone': timezone,
          'current_time': currentTime,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final result = ReminderParseResult.fromJson(response.data);
      
      // Explicitly check permissions here
      final permission = await _reminderService.checkPermissions();
      if (permission == 'notDetermined') {
        state = state.copyWith(
          status: SmartReminderStatus.needsPermission,
          parseResult: result,
        );
      } else if (permission == 'denied') {
        state = state.copyWith(
          status: SmartReminderStatus.permissionDenied,
          parseResult: result,
        );
      } else {
        state = state.copyWith(
          status: SmartReminderStatus.prompting,
          parseResult: result,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SmartReminderStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      _isFetching = false;
    }
  }

  Future<void> executeRouting() async {
    if (_isFetching) return;
    _isFetching = true;

    final result = state.parseResult;
    if (result == null) {
      _isFetching = false;
      return;
    }

    state = state.copyWith(status: SmartReminderStatus.executing);

    try {
      // Check permissions first
      final permission = await _reminderService.checkPermissions();
      if (permission == 'denied') {
        state = state.copyWith(status: SmartReminderStatus.permissionDenied);
        return;
      } else if (permission == 'notDetermined') {
        final granted = await _reminderService.requestPermissions();
        if (!granted) {
          state = state.copyWith(status: SmartReminderStatus.permissionDenied);
          return;
        }
      }

      final success = await _reminderService.createReminder(
        title: result.action,
        triggerTime: result.triggerTime,
        recurrence: result.recurrence.toMap(),
      );

      if (success) {
        state = state.copyWith(status: SmartReminderStatus.success);
      } else {
        state = state.copyWith(
          status: SmartReminderStatus.error,
          errorMessage: 'Failed to create native reminder',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SmartReminderStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      _isFetching = false;
    }
  }

  void reset() {
    state = SmartReminderState();
  }

  Future<void> requestPermission() async {
    if (_isFetching) return;
    _isFetching = true;
    
    try {
      final granted = await _reminderService.requestPermissions();
      if (granted) {
        // [Staff-Rule] await delay after auth
        await Future.delayed(const Duration(milliseconds: 500));
        state = state.copyWith(status: SmartReminderStatus.prompting);
      } else {
        state = state.copyWith(status: SmartReminderStatus.permissionDenied);
      }
    } catch (e) {
      state = state.copyWith(
        status: SmartReminderStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      _isFetching = false;
    }
  }

  Future<void> openSettings() async {
    await _reminderService.openSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
