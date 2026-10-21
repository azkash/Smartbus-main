import 'package:flutter/material.dart';

class GlobalCallBanner extends StatelessWidget {
  const GlobalCallBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Dinonaktifkan sesuai permintaan: cukup 1 notifikasi banner kecil dari native Android
    return const SizedBox.shrink();
  }
}
