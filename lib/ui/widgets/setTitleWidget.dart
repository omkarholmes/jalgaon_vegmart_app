import 'package:eshop/ui/styles/Color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget setHeadTitle(String title,BuildContext context) {
  return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12.0, end: 15.0),
      child: Text(title,
          style: Theme.of(context).textTheme.subtitle1!.copyWith(
              color: Theme.of(context).colorScheme.fontColor)));
}