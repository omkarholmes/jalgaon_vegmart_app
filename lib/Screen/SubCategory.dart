
import 'package:eshop/Helper/Session.dart';
import 'package:eshop/Model/Section_Model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:eshop/ui/styles/Color.dart';
import '../ui/styles/DesignConfig.dart';
import '../ui/widgets/AppBarWidget.dart';
import 'ProductList.dart';

class SubCategory extends StatelessWidget {
  final List<Product>? subList;
  final String title;

  const SubCategory({Key? key, this.subList, required this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getAppBar(title, context),
      body: GridView.count(
          padding: const EdgeInsets.all(20),
          crossAxisCount: 3,
          shrinkWrap: true,
          childAspectRatio: .75,
          children: List.generate(
            subList!.length,
            (index) {
              return subCatItem(index, context);
            },
          )),
    );
  }

  subCatItem(int index, BuildContext context) {
    return InkWell(
      child: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: FadeInImage(
                    image: NetworkImage(subList![index].image!),
                    fadeInDuration: const Duration(milliseconds: 150),
                    imageErrorBuilder: (context, error, stackTrace) =>
                        erroWidget(50),
                    placeholder: placeHolder(50),
                  )),
            ),
          ),
          Text(
            "${capitalize(subList![index].name!.toLowerCase())}\n",
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .caption!
                .copyWith(color: Theme.of(context).colorScheme.fontColor,fontSize: 9),
          )
        ],
      ),
      onTap: () {
        if (subList![index].subList == null ||
            subList![index].subList!.isEmpty) {
          Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => ProductList(
                  name: subList![index].name,
                  id: subList![index].id,
                  tag: false,
                  fromSeller: false,
                ),
              ));
        } else {
          Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => SubCategory(
                  subList: subList![index].subList,
                  title: subList![index].name!.toUpperCase() ,
                ),
              ));
        }
      },
    );
  }
}
