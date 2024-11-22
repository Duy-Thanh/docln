import 'package:flutter/material.dart';
import '../../services/update_service.dart';
import 'update_dialog.dart';

class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  void _checkForUpdates() async {
    final updateInfo = await UpdateService.checkForUpdates();
    if (updateInfo != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => UpdateDialog(updateInfo: updateInfo),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}