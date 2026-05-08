import 'package:flutter/services.dart';

/// Build a shareable URL that auto-fills the right game and code on launch.
///
/// On Flutter Web `Uri.base` is the page's URL, so this produces something
/// like `https://onlinefish.web.app/?game=cambio&code=AB7K3`. On native
/// builds `Uri.base` is `file:///`, so the link is mostly useful when the
/// app is deployed to web.
String buildInviteUrl({required String game, required String code}) {
  final base = Uri.base;
  final origin = base.origin;
  final path = base.path.isEmpty ? '/' : base.path;
  return '$origin$path?game=$game&code=$code';
}

Future<void> copyInviteLink({
  required String game,
  required String code,
}) =>
    Clipboard.setData(
        ClipboardData(text: buildInviteUrl(game: game, code: code)));
