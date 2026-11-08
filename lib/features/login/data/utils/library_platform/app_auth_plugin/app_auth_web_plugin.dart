import 'dart:convert';
import 'dart:math';

import 'package:flutter_appauth_platform_interface/flutter_appauth_platform_interface.dart';
import 'package:flutter_appauth_web/authorization_exception.dart';
import 'package:flutter_appauth_web/flutter_appauth_web.dart' as upstream;
import 'package:web/web.dart' as web;

export 'package:flutter_appauth_web/flutter_appauth_web.dart'
    hide AppAuthWebPlugin;

/// Adds one-time OAuth state validation to the pinned web plugin.
class AppAuthWebPlugin extends upstream.AppAuthWebPlugin {
  static const _stateStorage = 'auth_request_state';
  static const _responseStorage = 'auth_info';
  Uri? _redirectUri;

  @override
  Future<AuthorizationResponse> authorize(AuthorizationRequest request) async {
    final originalParameters = request.additionalParameters;
    try {
      _redirectUri = Uri.parse(request.redirectUrl);
      final callback = web.window.sessionStorage.getItem(_responseStorage);
      if (callback != null) {
        // Validate before the upstream implementation consumes the PKCE verifier.
        _validateCallback(callback);
      } else {
        final random = Random.secure();
        final state = base64Url
            .encode(List<int>.generate(32, (_) => random.nextInt(256)))
            .replaceAll('=', '');
        web.window.sessionStorage.setItem(_stateStorage, state);
        // The pinned plugin concatenates these parameters without encoding.
        request.additionalParameters = {
          for (final entry
              in (originalParameters ?? <String, String>{}).entries)
            if (entry.key != 'state')
              Uri.encodeQueryComponent(entry.key): Uri.encodeQueryComponent(
                entry.value,
              ),
          'state': state,
        };
      }
      return await super.authorize(request);
    } on AutoRedirectToAppAfterStoreAuthorizeDestinationUrlException {
      // Navigation resumes in a new page; retain the pending transaction.
      rethrow;
    } catch (_) {
      _clearTransaction();
      rethrow;
    } finally {
      request.additionalParameters = originalParameters;
      _redirectUri = null;
    }
  }

  @override
  AuthorizationResponse processLoginResult(
    String loginResult,
    String codeVerifier,
  ) {
    try {
      _validateCallback(loginResult);
      return super.processLoginResult(loginResult, codeVerifier);
    } finally {
      _clearTransaction();
    }
  }

  void _validateCallback(String callback) {
    final uri = Uri.tryParse(callback);
    final redirect = _redirectUri;
    final pendingState = web.window.sessionStorage.getItem(_stateStorage);
    if (uri == null ||
        redirect == null ||
        !uri.hasAuthority ||
        uri.scheme != redirect.scheme ||
        uri.host != redirect.host ||
        uri.port != redirect.port ||
        uri.userInfo.isNotEmpty ||
        uri.path != redirect.path ||
        uri.hasFragment) {
      throw StateError('Invalid OAuth callback URL');
    }
    final parameters = uri.queryParametersAll;
    final states = parameters['state'];
    final codes = parameters['code'];
    if (pendingState == null ||
        pendingState.isEmpty ||
        states == null ||
        states.length != 1 ||
        states.single.isEmpty ||
        states.single != pendingState ||
        codes == null ||
        codes.length != 1 ||
        codes.single.isEmpty ||
        parameters.containsKey('error')) {
      throw StateError('Invalid OAuth authorization response');
    }
  }

  void _clearTransaction() {
    for (final key in [
      _stateStorage,
      _responseStorage,
      'auth_code_verifier',
      'auth_destination_url',
    ]) {
      web.window.sessionStorage.removeItem(key);
    }
  }
}
