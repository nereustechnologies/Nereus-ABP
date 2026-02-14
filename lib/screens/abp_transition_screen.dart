import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/s3_upload_service.dart';

class AbpTransitionScreen extends StatefulWidget {
  final String title;
  final String message;
  final String? csvKey;

  const AbpTransitionScreen({
    super.key,
    this.title = "Block Complete",
    this.message = "Take a breath. Continue when ready.",
    this.csvKey,
  });

  @override
  State<AbpTransitionScreen> createState() => _AbpTransitionScreenState();
}

class _AbpTransitionScreenState extends State<AbpTransitionScreen> {
  bool isDownloading = false;

  Future<void> _downloadCsv() async {
    if (widget.csvKey == null) return;

    setState(() => isDownloading = true);

    try {
      final url = await S3UploadService.generateDownloadUrl(key: widget.csvKey!);

      final uri = Uri.parse(url);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw "Could not open download link";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }

    setState(() => isDownloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasCsv = widget.csvKey != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle,
                  color: Colors.greenAccent, size: 80),
              const SizedBox(height: 22),

              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              if (hasCsv)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isDownloading ? null : _downloadCsv,
                    child: isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Download CSV",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

              if (hasCsv) const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Continue",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
