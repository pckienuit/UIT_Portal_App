import 'package:flutter_riverpod/legacy.dart';

import 'auth_controller.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController();
});
