import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/localization/l10n_extension.dart';
import '../../services/network_service.dart';

/// Show "No internet" dialog. Call when API fails due to no connectivity.
void showNoInternetDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('no.internet.title')),
      content: Text(ctx.t('no.internet.message')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.t('common.close')),
        ),
      ],
    ),
  );
}

/// Check connectivity before an async operation. If offline, shows dialog and returns false.
Future<bool> ensureConnectedAndShowDialog(BuildContext context) async {
  final connected = await NetworkService.ensureConnected();
  if (!connected && context.mounted) {
    showNoInternetDialog(context);
    return false;
  }
  return connected;
}

/// Show dialog when camera/mic permission is denied, with button to open app settings.
void showPermissionDeniedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('permission.denied.title')),
      content: Text(ctx.t('permission.denied.message')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.t('common.cancel')),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            openAppSettings();
          },
          child: Text(ctx.t('permission.open.settings')),
        ),
      ],
    ),
  );
}
