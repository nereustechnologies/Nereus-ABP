import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
// import 'package:aws_common/aws_common.dart';
// import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class S3UploadService {
  static const String region = "us-east-1";
  static const String bucketName = "nereus-abp";
  static const String accessKey = "";
  static const String secretKey = "";

  static Future<String> uploadCsv({
    required File file,
    required String userId,
    required String sessionId,
    required String exerciseId,
  }) async {
    final s3 = S3(
      region: region,
      credentials: AwsClientCredentials(
        accessKey: accessKey,
        secretKey: secretKey,
      ),
    );

    assert(userId.trim().isNotEmpty, 'userId must not be empty');

    final key = "$userId/$sessionId/$exerciseId.csv";

    // debug: show which user/session/exercise the file will be uploaded under
    debugPrint("🔧 S3UploadService.uploadCsv -> userId: $userId, sessionId: $sessionId, exerciseId: $exerciseId, key: $key");

    final Uint8List bytes = await file.readAsBytes();
    debugPrint("🔧 CSV size: ${bytes.length} bytes; uploading to s3://$bucketName/$key");

    await s3.putObject(
      bucket: bucketName,
      key: key,
      body: bytes,
      contentType: "text/csv",
    );

    debugPrint("✅ S3 upload complete for key: $key");

    return key;
  }

  static Future<String> generateDownloadUrl({
    required String key,
    Duration expiry = const Duration(minutes: 15),
  }) async {
    final now = DateTime.now().toUtc();
    final dateStamp = _formatDateStamp(now);
    final amzDate = _formatAmzDate(now);
    final expiresInSeconds = expiry.inSeconds;

    // Build credential scope
    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final credential = '$accessKey/$credentialScope';

    // Build canonical request
    final host = 's3.$region.amazonaws.com';
    final canonicalUri = '/$bucketName/$key';
    final canonicalQueryString = 
        'X-Amz-Algorithm=AWS4-HMAC-SHA256'
        '&X-Amz-Credential=${Uri.encodeComponent(credential)}'
        '&X-Amz-Date=$amzDate'
        '&X-Amz-Expires=$expiresInSeconds'
        '&X-Amz-SignedHeaders=host';

    final canonicalHeaders = 'host:$host\n';
    final signedHeaders = 'host';
    final payloadHash = 'UNSIGNED-PAYLOAD';

    final canonicalRequest = 
        'GET\n'
        '$canonicalUri\n'
        '$canonicalQueryString\n'
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';

    // Create string to sign
    final canonicalRequestHash = _sha256Hash(canonicalRequest);
    final stringToSign = 
        'AWS4-HMAC-SHA256\n'
        '$amzDate\n'
        '$credentialScope\n'
        '$canonicalRequestHash';

    // Calculate signature
    final signature = _calculateSignature(secretKey, dateStamp, region, stringToSign);

    // Build final URL
    final url = 'https://$host$canonicalUri?$canonicalQueryString&X-Amz-Signature=$signature';
    
    return url;
  }

  static String _formatDateStamp(DateTime date) {
    return '${date.year}${_pad(date.month)}${_pad(date.day)}';
  }

  static String _formatAmzDate(DateTime date) {
    return '${_formatDateStamp(date)}T${_pad(date.hour)}${_pad(date.minute)}${_pad(date.second)}Z';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static String _sha256Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String _calculateSignature(
    String secretKey,
    String dateStamp,
    String region,
    String stringToSign,
  ) {
    final kDate = _hmacSha256('AWS4$secretKey'.codeUnits, dateStamp.codeUnits);
    final kRegion = _hmacSha256(kDate, region.codeUnits);
    final kService = _hmacSha256(kRegion, 's3'.codeUnits);
    final kSigning = _hmacSha256(kService, 'aws4_request'.codeUnits);
    final signature = _hmacSha256(kSigning, stringToSign.codeUnits);
    
    return signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }

}
