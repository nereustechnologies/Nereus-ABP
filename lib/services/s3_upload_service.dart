import 'dart:io';
import 'dart:typed_data';

import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';

class S3UploadService {
  static const String region = "us-east-1";
  static const String bucketName = "nereus-abp";
  static const String accessKey = "AKIA5CK6AL244FQYVWAK";
  static const String secretKey = "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";

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

    final key = "$userId/$sessionId/$exerciseId.csv";
    final Uint8List bytes = await file.readAsBytes();

    await s3.putObject(
      bucket: bucketName,
      key: key,
      body: bytes,
      contentType: "text/csv",
    );

    return key;
  }

  static Future<String> generateDownloadUrl({
    required String key,
    Duration expiry = const Duration(minutes: 15),
  }) async {
    final credentials = AWSCredentials(accessKey, secretKey);

    final signer = AWSSigV4Signer(
      credentialsProvider: AWSCredentialsProvider(credentials),
    );

    final scope = AWSCredentialScope(
      region: region,
      service: AWSService.s3,
    );

    final request = AWSHttpRequest(
      method: AWSHttpMethod.get,
      uri: Uri.parse(
        "https://$bucketName.s3.$region.amazonaws.com/$key",
      ),
    );

    final presignedRequest = await signer.presign(
      request,
      credentialScope: scope,
      expiresIn: expiry,
    );

    return presignedRequest.toString();
  }
}
