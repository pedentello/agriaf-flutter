// ignore_for_file: unnecessary_null_comparison

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:openid_client/openid_client.dart';
import 'package:openid_client/openid_client_io.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

const FlutterSecureStorage secureStorage = FlutterSecureStorage();

/// -----------------------------------
///           Auth2 Variables
/// -----------------------------------

const String _clientId = 'bG7I9fOTjWso0_OczaQrWnzZlOsv-kxJtwK65MmWzLA';
const String _issuer = 'https://am.agriaf.com.br/auth/oidc';

final List<String> _scopes = <String>[
  'openid',
  'profile',
  'email',
  'offline_access'
];
String logoutUrl = "";

/// -----------------------------------
///           Profile Widget
/// -----------------------------------

class Profile extends StatelessWidget {
  final Future<void> Function() logoutAction;
  final String name;
  final String picture;

  const Profile(this.logoutAction, this.name, this.picture, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 4),
            shape: BoxShape.circle,
            image: DecorationImage(
              fit: BoxFit.fill,
              image: NetworkImage(picture),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Name: $name'),
        const SizedBox(height: 48),
        RaisedButton(
          onPressed: () async {
            await logoutAction();
          },
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

/// -----------------------------------
///            Login Widget
/// -----------------------------------

class Login extends StatelessWidget {
  final Future<void> Function() loginAction;
  final String loginError;

  const Login(this.loginAction, this.loginError, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        RaisedButton(
          onPressed: () async {
            await loginAction();
          },
          child: const Text('Login'),
        ),
        Text(loginError),
      ],
    );
  }
}

/// -----------------------------------
///                 App
/// -----------------------------------

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

/// -----------------------------------
///              App State
/// -----------------------------------

class _MyAppState extends State<MyApp> {
  bool isBusy = false;
  bool isLoggedIn = false;
  String errorMessage = "";
  String name = "";
  String picture = "";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agriaf Demo',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Agriaf Demo'),
        ),
        body: Center(
          child: isBusy
              ? const CircularProgressIndicator()
              : isLoggedIn
                  ? Profile(logoutAction, name, picture)
                  : Login(loginAction, errorMessage),
        ),
      ),
    );
  }

  Future<TokenResponse> reAuthenticate(
      Uri uri, String clientId, String storedRefreshToken) async {
    // create the client
    var issuer = await Issuer.discover(uri);
    var client = Client(issuer, clientId);

    var c = client.createCredential(refreshToken: storedRefreshToken);

    var res = await c.getTokenResponse(true);

    return res;
  }

  Future<TokenResponse> authenticate(
      Uri uri, String clientId, List<String> scopes) async {
    // create the client
    var issuer = await Issuer.discover(uri);
    var client = Client(issuer, clientId);

    // create a function to open a browser with an url

    urlLauncher(String url) async {
      if (await canLaunch(url)) {
        await launch(url, forceWebView: true);
      } else {
        throw 'Could not launch $url';
      }
    }

    // create an authenticator
    var authenticator = Authenticator(
      client,
      scopes: scopes,
      urlLancher: urlLauncher,
      port: 3000,
    );

    // starts the authentication
    var c = await authenticator.authorize();

    // close the webview when finished
    closeWebView();

    var res = await c.getTokenResponse();
    setState(() {
      logoutUrl = c.generateLogoutUrl().toString();
    });

    // get userinfo
    var info = await c.getUserInfo();
    print(info.name);

    // get claims from id token if present
    //print(res.idToken.claims.name.toString());

    return res;
  }

  Future<void> loginAction() async {
    setState(() {
      isBusy = true;
      errorMessage = '';
    });

    try {
      var result = await authenticate(Uri.parse(_issuer), _clientId, _scopes);

      if (result != null && result.idToken != null) {
        await secureStorage.write(
            key: 'refresh_token', value: result.refreshToken);
        setState(() {
          isBusy = false;
          isLoggedIn = true;
          name = result.idToken.claims.name.toString();
          picture = result.idToken.claims.picture.toString();
        });
      } else {
        setState(() {
          isBusy = false;
          isLoggedIn = false;
        });
      }
    } on Exception catch (e, s) {
      debugPrint('login error: $e - stack: $s');

      setState(() {
        isBusy = false;
        isLoggedIn = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> logoutAction() async {
    //await secureStorage.delete(key: 'refresh_token');
    setState(() {
      isLoggedIn = false;
      isBusy = false;
    });
  }

  @override
  void initState() {
    initAction();
    super.initState();
  }

  Future<void> initAction() async {
    final String storedRefreshToken =
        await secureStorage.read(key: 'refresh_token');
    if (storedRefreshToken == null) return;

    setState(() {
      isBusy = true;
    });

    try {
      var result = await reAuthenticate(
          Uri.parse(_issuer), _clientId, storedRefreshToken);

      if (result != null && result.idToken != null) {
        await secureStorage.write(
            key: 'refresh_token', value: result.refreshToken);
        setState(() {
          isBusy = false;
          isLoggedIn = true;
          name = result.idToken.claims.name.toString();
          picture = result.idToken.claims.picture.toString();
        });
      } else {
        setState(() {
          isBusy = false;
          isLoggedIn = false;
        });
      }
    } on Exception catch (e, s) {
      debugPrint('error on refresh token: $e - stack: $s');
      await logoutAction();
    }
  }
}
