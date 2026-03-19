import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/file_service.dart';

class UploadState {
  final bool isUploading;
  final double progress;
  final String? error;
  final CancelToken? cancelToken;

  UploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.error,
    this.cancelToken,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    CancelToken? cancelToken,
    bool clearError = false,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
      cancelToken: cancelToken ?? this.cancelToken,
    );
  }
}

class UploadController extends StateNotifier<UploadState> with WidgetsBindingObserver {
  final FileService _fileService;
  final Ref _ref;

  UploadController(this._fileService, this._ref) : super(UploadState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.cancelToken?.cancel();
    super.dispose();
  }

  Future<bool> uploadFile(File file) async {
    final cancelToken = CancelToken();
    state = state.copyWith(
      isUploading: true, 
      progress: 0.0, 
      cancelToken: cancelToken,
      clearError: true,
    );

    try {
      await _fileService.uploadFile(
        file,
        cancelToken: cancelToken,
        onSendProgress: (count, total) {
          if (total > 0 && mounted) {
            final progress = (count / total) * 0.9;
            // The upload is finished (data sent), but the server needs time to index in the background 
            // if we were polling. For now progress reflects the file transfer capped at 90%.
            state = state.copyWith(progress: progress);
          }
        },
      );
      if (mounted) {
        state = state.copyWith(isUploading: false, progress: 1.0, cancelToken: null);
        _ref.invalidate(filesProvider);
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      
      if (e is DioException && e.type == DioExceptionType.cancel) {
        state = state.copyWith(isUploading: false, error: 'Upload cancelled', cancelToken: null);
      } else {
        state = state.copyWith(isUploading: false, error: e.toString(), cancelToken: null);
      }
      return false;
    }
  }

  void cancelUpload() {
    state.cancelToken?.cancel();
    if (mounted) {
      state = state.copyWith(isUploading: false, cancelToken: null, error: 'Upload cancelled');
    }
  }
}

final uploadControllerProvider = StateNotifierProvider<UploadController, UploadState>((ref) {
  return UploadController(ref.read(fileServiceProvider), ref);
});
