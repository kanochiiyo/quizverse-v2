import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CategoryModel {
  final int id;
  final String name;
  final IconData iconData;

  CategoryModel({required this.id, required this.name, required this.iconData});

  static final Map<int, IconData> _categoryIcons = {
    9: FontAwesomeIcons.globe,
    10: FontAwesomeIcons.book,
    11: FontAwesomeIcons.film,
    12: FontAwesomeIcons.music,
    13: FontAwesomeIcons.masksTheater,
    14: FontAwesomeIcons.tv,
    15: FontAwesomeIcons.gamepad,
    16: FontAwesomeIcons.chessBoard,
    17: FontAwesomeIcons.flask,
    18: FontAwesomeIcons.computer,
    19: FontAwesomeIcons.calculator,
    20: FontAwesomeIcons.dragon,
    21: FontAwesomeIcons.baseball,
    22: FontAwesomeIcons.mapLocationDot,
    23: FontAwesomeIcons.landmark,
    24: FontAwesomeIcons.userGroup,
    25: FontAwesomeIcons.palette,
    26: FontAwesomeIcons.star,
    27: FontAwesomeIcons.paw,
    28: FontAwesomeIcons.car,
    29: FontAwesomeIcons.commentDots,
    30: FontAwesomeIcons.mobileScreenButton,
    31: FontAwesomeIcons.faceGrinBeam,
    32: FontAwesomeIcons.wandMagicSparkles,
  };

  static const IconData _defaultIcon = CupertinoIcons.question_circle_fill;

  static IconData _getIconById(int id) {
    return _categoryIcons[id] ?? _defaultIcon;
  }

  // Ubah dari JSON ke Map supaya bisa dipakai oleh Flutter
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    int id = json['id'] as int;

    return CategoryModel(
      id: id,
      name: json['name'] as String,
      iconData: _getIconById(id),
    );
  }
}
