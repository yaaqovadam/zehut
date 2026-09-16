import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';

// 🎯 NATIVE DEVICE CLIPPER SERVICE (With Real Error Reporting & User-Agent)
class VideoClipperService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<File> clipVideo({
    required String url,
    required int startSec,
    required int endSec,
    required String outputTitle,
  }) async {
    try {
      debugPrint("1. Resolving YouTube stream on phone...");
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      // Select highest quality muxed stream (video + audio combined)
      final streamInfo = manifest.muxed.withHighestBitrate();
      final streamUrl = streamInfo.url.toString();

      final duration = (endSec > startSec) ? (endSec - startSec) : 15;
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/$outputTitle.mp4';

      final existingFile = File(outputPath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      debugPrint("2. Executing native FFmpeg with browser headers...");
      // -user_agent prevents YouTube's CDN from dropping the connection with a 403 Forbidden
      final command = '-user_agent "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15" '
          '-ss $startSec -i "$streamUrl" -t $duration -c copy -avoid_negative_ts make_zero "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists() && await file.length() > 0) {
          debugPrint("3. Clip ready on device at: $outputPath");
          return file;
        } else {
          throw Exception("FFmpeg completed but output file is empty.");
        }
      } else {
        final logs = await session.getAllLogsAsString();
        final failStackTrace = await session.getFailStackTrace();
        debugPrint("FFmpeg Error Logs: $logs");
        throw Exception("FFmpeg failed: ${logs ?? failStackTrace ?? 'Unknown FFmpeg exit'}");
      }
    } catch (e) {
      debugPrint("Clipper error: $e");
      rethrow; // Surface the exact underlying error to the UI
    } finally {
      _yt.close();
    }
  }
}