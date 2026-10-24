import '../models/admin_account.dart';
import '../models/camera.dart';
import '../models/video_recording.dart';

abstract interface class AdminRepository {
  Future<List<Camera>> fetchCameras();
  Future<Camera> createCamera({
    required String name,
    String? location,
    String? streamUrl,
  });
  Future<Camera> updateCamera(
    String id, {
    required String name,
    String? location,
    String? streamUrl,
    required bool enabled,
  });
  Future<void> deleteCamera(String id);

  Future<List<VideoRecording>> fetchRecordings({
    String? cameraId,
    bool? withoutCamera,
    DateTime? from,
    DateTime? to,
  });
  Future<VideoRecording> createRecording({
    String? cameraId,
    required String title,
    String? eventType,
    required DateTime recordedAt,
    int? durationSeconds,
    required String videoUrl,
  });
  Future<VideoRecording> updateRecording(
    String id, {
    String? cameraId,
    required String title,
    String? eventType,
    required DateTime recordedAt,
    int? durationSeconds,
    required String videoUrl,
  });
  Future<void> deleteRecording(String id);

  Future<List<AdminAccount>> fetchAccounts();
  Future<AdminAccount> createAccount({
    required String username,
    required String password,
    required String role,
  });
  Future<AdminAccount> setAccountEnabled(String id, bool enabled);
}
