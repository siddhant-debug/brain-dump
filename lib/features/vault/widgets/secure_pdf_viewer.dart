import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/controllers/auth_controller.dart';

class SecurePdfViewer extends ConsumerStatefulWidget {
  final int fileId;
  final String filename;

  const SecurePdfViewer({
    super.key,
    required this.fileId,
    required this.filename,
  });

  @override
  ConsumerState<SecurePdfViewer> createState() => _SecurePdfViewerState();
}

class _SecurePdfViewerState extends ConsumerState<SecurePdfViewer> {
  String? _token;
  bool _isLoadingToken = true;

  @override
  void initState() {
    super.initState();
    _fetchToken();
  }

  Future<void> _fetchToken() async {
    final token = await ref.read(authControllerProvider.notifier).getToken();
    if (mounted) {
      setState(() {
        _token = token;
        _isLoadingToken = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingToken) {
      return Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: AppBar(
          title: Text(widget.filename),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white24),
        ),
      );
    }

    if (_token == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: AppBar(
          title: Text(widget.filename),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Authentication error',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final url =
        '${ApiConstants.baseUrl}/files/vault/documents/${widget.fileId}';

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: Text(widget.filename),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: SfPdfViewer.network(
        url,
        headers: {'Authorization': 'Bearer $_token'},
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          debugPrint('PDF Load Failed: ${details.error}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load PDF: ${details.error}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
      ),
    );
  }
}
