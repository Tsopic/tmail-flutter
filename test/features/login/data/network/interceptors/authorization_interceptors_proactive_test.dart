import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model/account/personal_account.dart';
import 'package:model/oidc/token_oidc.dart';
import 'package:tmail_ui_user/features/login/data/local/account_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/local/token_oidc_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/network/authentication_client/authentication_client_base.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/main/exceptions/remote/authentication_exception.dart';
import 'package:tmail_ui_user/main/utils/ios_sharing_manager.dart';

import '../../../../../fixtures/account_fixtures.dart';
import '../../../../../fixtures/oidc_fixtures.dart';

class _RefreshClient extends Fake implements AuthenticationClientBase {
  final result = Completer<TokenOIDC>();
  int calls = 0;

  @override
  Future<TokenOIDC> refreshingTokensOIDC(
    String clientId,
    String redirectUrl,
    String discoveryUrl,
    List<String> scopes,
    TokenOIDC currentToken,
  ) {
    calls++;
    return result.future;
  }
}

class _Tokens extends Fake implements TokenOidcCacheManager {
  int writes = 0;
  @override
  Future<void> persistOneTokenOidc(TokenOIDC token) async {
    writes++;
  }
}

class _Accounts extends Fake implements AccountCacheManager {
  @override
  Future<PersonalAccount> getCurrentAccount() async =>
      AccountFixtures.aliceAccount;
  @override
  Future<void> setCurrentAccount(PersonalAccount account) async {}
}

class _Sharing extends Fake implements IOSSharingManager {}

class _Adapter implements HttpClientAdapter {
  final rejected = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final isNew =
        options.headers[HttpHeaders.authorizationHeader] == 'Bearer new';
    if (!isNew && !rejected.isCompleted) rejected.complete();
    return ResponseBody.fromString(
      '{}',
      isNew ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _RefreshClient client;
  late _Tokens tokens;
  late AuthorizationInterceptors interceptors;

  setUp(() {
    dio = Dio();
    client = _RefreshClient();
    tokens = _Tokens();
    interceptors = AuthorizationInterceptors(
      dio,
      client,
      tokens,
      _Accounts(),
      _Sharing(),
    );
    dio.interceptors.add(interceptors);
    interceptors.setTokenAndAuthorityOidc(
      newToken: TokenOIDC(
        'old',
        OIDCFixtures.newTokenOidc.tokenId,
        'refresh',
        expiredTime: DateTime.now().add(const Duration(seconds: 10)),
      ),
      newConfig: OIDCFixtures.oidcConfiguration,
    );
  });

  tearDown(() => interceptors.clear());

  test(
    'default scheduling refreshes a near-expiry token without a request',
    () async {
      await Future<void>.delayed(Duration.zero);
      expect(client.calls, 1);
      client.result.complete(
        TokenOIDC(
          'new',
          OIDCFixtures.newTokenOidc.tokenId,
          'refresh',
          expiredTime: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tokens.writes, 1);
      expect(interceptors.currentToken, 'new');
    },
  );

  test(
    'proactive and explicit refresh share one request and persistence',
    () async {
      final proactive = interceptors.checkAndRefreshTokenIfNeeded();
      final explicit = interceptors.requestTokenRefresh();
      expect(client.calls, 1);
      client.result.complete(
        TokenOIDC(
          'new',
          OIDCFixtures.newTokenOidc.tokenId,
          'refresh',
          expiredTime: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await proactive;
      final acquired = await explicit;
      expect(tokens.writes, 1);
      expect(interceptors.currentToken, 'new');
      expect(interceptors.currentTokenOidc, acquired);
    },
  );

  test('401 retry joins a proactive refresh already in flight', () async {
    final adapter = _Adapter();
    dio.httpClientAdapter = adapter;
    final proactive = interceptors.checkAndRefreshTokenIfNeeded();
    final response = dio.get<dynamic>('https://example.com/jmap');
    await adapter.rejected.future;
    await Future<void>.delayed(Duration.zero);
    expect(client.calls, 1);
    client.result.complete(
      TokenOIDC(
        'new',
        OIDCFixtures.newTokenOidc.tokenId,
        'refresh',
        expiredTime: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await proactive;
    expect((await response).statusCode, 200);
    expect(client.calls, 1);
    expect(tokens.writes, 1);
  });

  test(
    'clear prevents a pending proactive refresh from restoring the session',
    () async {
      final proactive = interceptors.checkAndRefreshTokenIfNeeded();
      final explicit = interceptors.requestTokenRefresh();
      final rejected = expectLater(
        explicit,
        throwsA(isA<StaleSessionRefreshException>()),
      );
      interceptors.clear();
      client.result.complete(OIDCFixtures.newTokenOidc);
      await proactive;
      await rejected;
      expect(tokens.writes, 0);
      expect(interceptors.currentToken, isNull);
      expect(interceptors.currentTokenOidc, isNull);
    },
  );
}
