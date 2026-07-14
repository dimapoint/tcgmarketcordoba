import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

// En web GIS no permite UI propia: el botón lo renderiza Google y el
// resultado llega por GoogleSignIn.instance.authenticationEvents.
Widget renderGoogleButton() => web.renderButton();
