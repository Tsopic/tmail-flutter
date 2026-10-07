import 'dart:async';

import 'package:core/utils/app_logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  StreamController<Map<String, dynamic>>? backgroundMessageStreamController;
  StreamController<String?>? fcmTokenStreamController;

  FcmService._internal();

  static final FcmService _instance = FcmService._internal();

  static FcmService get instance => _instance;

  void handleFirebaseBackgroundMessage(RemoteMessage newRemoteMessage) {
    log(
      'FcmService::handleFirebaseBackgroundMessage():dataKeys: ${newRemoteMessage.data.keys.toList()}',
    );
    if (newRemoteMessage.data.isNotEmpty) {
      if (backgroundMessageStreamController?.isClosed == false) {
        backgroundMessageStreamController?.add(newRemoteMessage.data);
      }
    }
  }

  void handleToken(String? token) {
    log('FcmService::handleToken():hasToken: ${token != null}');
    if (fcmTokenStreamController?.isClosed == false) {
      fcmTokenStreamController?.add(token);
    }
  }

  void initialStreamController() {
    log('FcmService::initialStreamController:');
    if (backgroundMessageStreamController?.isClosed != false) {
      backgroundMessageStreamController =
          StreamController<Map<String, dynamic>>.broadcast();
    }
    if (fcmTokenStreamController?.isClosed != false) {
      fcmTokenStreamController = StreamController<String?>.broadcast();
    }
  }

  Future<void> closeStream() async {
    final backgroundController = backgroundMessageStreamController;
    final tokenController = fcmTokenStreamController;
    backgroundMessageStreamController = null;
    fcmTokenStreamController = null;

    try {
      if (backgroundController?.isClosed == false) {
        await backgroundController?.close();
      }
    } catch (e) {
      logWarning(
        'FcmService::closeStream: backgroundMessageStreamController throw exception: $e',
      );
    }
    try {
      if (tokenController?.isClosed == false) {
        await tokenController?.close();
      }
    } catch (e) {
      logWarning(
        'FcmService::closeStream: fcmTokenStreamController throw exception: $e',
      );
    }
  }
}
