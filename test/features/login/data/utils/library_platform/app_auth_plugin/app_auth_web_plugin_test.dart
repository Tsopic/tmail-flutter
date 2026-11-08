@TestOn('chrome')
library;

import 'package:web/web.dart' as web;

import 'package:flutter_appauth_platform_interface/flutter_appauth_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/login/data/utils/library_platform/app_auth_plugin/app_auth_web_plugin.dart';

const redirectUrl = 'https://mail.example.com/auth.html';
const state = 'expected-state';
const transactionKeys = [
  'auth_request_state',
  'auth_info',
  'auth_code_verifier',
  'auth_destination_url',
];
const configuration = AuthorizationServiceConfiguration(
  authorizationEndpoint: 'https://identity.example.com/authorize',
  tokenEndpoint: 'https://identity.example.com/token',
);

class SilentPlugin extends AppAuthWebPlugin {
  String? authorizationUrl;

  @override
  Future<String> openIframe(String url, String name) async {
    authorizationUrl = url;
    final generatedState = Uri.parse(url).queryParameters['state'];
    expect(
      web.window.sessionStorage.getItem('auth_request_state'),
      generatedState,
    );
    return '$redirectUrl?state=$generatedState&code=authorization-code';
  }
}

class TokenPlugin extends AppAuthWebPlugin {
  int exchanges = 0;

  @override
  Future<TokenResponse> requestToken(TokenRequest request) async {
    exchanges++;
    expect(request.authorizationCode, 'authorization-code');
    expect(request.codeVerifier, 'pkce-verifier');
    return TokenResponse('access', 'refresh', null, 'id', 'Bearer', null, null);
  }
}

void main() {
  AuthorizationRequest request({bool silent = false}) => AuthorizationRequest(
    'client',
    redirectUrl,
    serviceConfiguration: configuration,
    scopes: ['openid'],
    promptValues: silent ? ['none'] : null,
    additionalParameters: {'state': 'untrusted', 'hint': 'a&state=injected'},
  );

  void seed(String callback, {bool pending = true}) {
    if (pending) web.window.sessionStorage.setItem('auth_request_state', state);
    web.window.sessionStorage.setItem('auth_info', callback);
    web.window.sessionStorage.setItem('auth_code_verifier', 'pkce-verifier');
    web.window.sessionStorage.setItem(
      'auth_destination_url',
      'https://mail.example.com',
    );
  }

  void expectClean() {
    for (final key in transactionKeys) {
      expect(web.window.sessionStorage.getItem(key), isNull, reason: key);
    }
  }

  setUp(() {
    for (final key in transactionKeys) {
      web.window.sessionStorage.removeItem(key);
    }
  });
  tearDown(() {
    for (final key in transactionKeys) {
      web.window.sessionStorage.removeItem(key);
    }
  });

  test(
    'generates unique 256-bit URL-safe state and preserves request parameters',
    () async {
      final plugin = SilentPlugin();
      final authRequest = request(silent: true);
      final originalParameters = authRequest.additionalParameters;
      final first = await plugin.authorize(authRequest);
      final firstState = Uri.parse(
        plugin.authorizationUrl!,
      ).queryParameters['state'];
      expect(firstState, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(first.authorizationCode, 'authorization-code');
      expect(first.codeVerifier, hasLength(128));
      expect(Uri.parse(plugin.authorizationUrl!).queryParametersAll['state'], [
        firstState,
      ]);
      expect(
        Uri.parse(plugin.authorizationUrl!).queryParameters['hint'],
        'a&state=injected',
      );
      expect(authRequest.additionalParameters, same(originalParameters));
      expectClean();
      await plugin.authorize(authRequest);
      expect(
        Uri.parse(plugin.authorizationUrl!).queryParameters['state'],
        isNot(firstState),
      );
      expectClean();
    },
  );

  test(
    'accepts matching callback and consumes state and PKCE verifier once',
    () async {
      seed('$redirectUrl?state=$state&code=authorization-code');
      final result = await AppAuthWebPlugin().authorize(request());
      expect(result.authorizationCode, 'authorization-code');
      expect(result.codeVerifier, 'pkce-verifier');
      expectClean();
      seed('$redirectUrl?state=$state&code=authorization-code', pending: false);
      await expectLater(
        AppAuthWebPlugin().authorize(request()),
        throwsStateError,
      );
      expectClean();
    },
  );

  test(
    'inherited token exchange runs only after successful validation',
    () async {
      final plugin = TokenPlugin();
      final tokenRequest = AuthorizationTokenRequest(
        'client',
        redirectUrl,
        serviceConfiguration: configuration,
        scopes: ['openid'],
      );
      seed('$redirectUrl?state=wrong&code=authorization-code');
      await expectLater(
        plugin.authorizeAndExchangeCode(tokenRequest),
        throwsStateError,
      );
      expect(plugin.exchanges, 0);
      expectClean();
      seed('$redirectUrl?state=$state&code=authorization-code');
      final response = await plugin.authorizeAndExchangeCode(tokenRequest);
      expect(response.accessToken, 'access');
      expect(plugin.exchanges, 1);
      expectClean();
    },
  );

  for (final callback in [
    '',
    'not a URL',
    '$redirectUrl?code=code',
    '$redirectUrl?state=&code=code',
    '$redirectUrl?state=wrong&code=code',
    '$redirectUrl?state=$state&state=$state&code=code',
    '$redirectUrl?state=$state&code=one&code=two',
    '$redirectUrl?state=$state',
    '$redirectUrl?state=$state&code=',
    '$redirectUrl?state=$state&code=code&error=access_denied',
    '$redirectUrl?state=$state&code=code#fragment',
    'https://evil.example.com/auth.html?state=$state&code=code',
    'http://mail.example.com/auth.html?state=$state&code=code',
    'https://mail.example.com:444/auth.html?state=$state&code=code',
    'https://mail.example.com/other.html?state=$state&code=code',
    'https://user@mail.example.com/auth.html?state=$state&code=code',
    '$redirectUrl?state=%XX&code=code',
  ]) {
    test(
      'rejects invalid callback and clears transaction: $callback',
      () async {
        seed(callback);
        await expectLater(
          AppAuthWebPlugin().authorize(request()),
          throwsStateError,
        );
        expectClean();
      },
    );
  }

  test(
    'clears transaction when upstream detects missing PKCE verifier',
    () async {
      seed('$redirectUrl?state=$state&code=code');
      web.window.sessionStorage.removeItem('auth_code_verifier');
      await expectLater(
        AppAuthWebPlugin().authorize(request()),
        throwsArgumentError,
      );
      expectClean();
    },
  );
}
