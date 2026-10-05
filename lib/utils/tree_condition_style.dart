import 'package:flutter/material.dart';
import '../models/tree_data.dart';
import '../theme/app_theme.dart';

Color treeConditionColor(TreeCondition condition) {
  switch (condition) {
    case TreeCondition.sehat:
      return AppColors.sehat;
    case TreeCondition.sakit:
      return AppColors.sakit;
    case TreeCondition.rawanTumbang:
      return AppColors.rawanTumbang;
  }
}