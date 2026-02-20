# 🔧 Streaming Timeout Fix

## Issue
The streaming chat was timing out after 60 seconds with the error:
```
DioException [receive timeout]: The request took longer than 0:01:00.000000 to receive data
```

## Root Cause
The `BrainService` Dio client had a global `receiveTimeout` of 60 seconds. When streaming responses, this timeout applies to the **entire stream duration**, not individual chunks. If the AI takes longer than 60 seconds to complete the full response, the stream is aborted.

## Solution
Added `receiveTimeout: Duration.zero` to the streaming request options, which **disables the timeout** for streaming requests only.

### Code Change
```dart
// In brain_service.dart, askBrain() method:

final response = await _dio.post(
  '/chat/chat',
  data: {'query': query},
  options: Options(
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'text/event-stream',
    },
    responseType: ResponseType.stream,
    receiveTimeout: Duration.zero, // ✅ No timeout for streaming
  ),
);
```

## Why This Works
- **Duration.zero** = No timeout
- Streaming responses can now run indefinitely
- Individual chunks still arrive quickly (no timeout needed)
- Regular (non-streaming) requests still use the 60s timeout from `BaseOptions`

## Testing
✅ `flutter analyze` - No issues found
✅ Ready to test in the app

## Alternative Solutions (Not Used)
1. **Increase timeout to 5 minutes**: `Duration(minutes: 5)`
   - ❌ Still arbitrary, could fail on very long responses
   
2. **Use separate Dio instance for streaming**:
   - ❌ More complex, unnecessary overhead

3. **Implement chunk-level timeout**:
   - ❌ Over-engineered for this use case

## Best Practice
For streaming endpoints:
- **Always disable or significantly increase `receiveTimeout`**
- The timeout should apply to chunk arrival, not total stream duration
- Dio's default behavior is designed for single-response requests, not streams

---

**Status**: ✅ Fixed and ready for testing!
