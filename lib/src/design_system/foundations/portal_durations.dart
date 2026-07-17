import 'package:flutter/animation.dart';

abstract final class PortalDurations {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const emphasizedCurve = Curves.easeOutCubic;
}
