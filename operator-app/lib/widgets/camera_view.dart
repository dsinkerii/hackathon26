// Platform-specific camera surface.
//
// * web: plain `<img>`, which renders `multipart/x-mixed-replace` MJPEG natively.
// * desktop/mobile: `media_kit`, which handles MJPEG, RTSP and files alike.
export 'camera_view_io.dart'
    if (dart.library.js_interop) 'camera_view_web.dart';
