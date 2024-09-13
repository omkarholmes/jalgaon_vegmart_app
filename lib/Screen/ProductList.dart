import 'dart:async';
import 'dart:math';

import 'package:eshop/Helper/SqliteData.dart';
import 'package:eshop/Provider/CartProvider.dart';
import 'package:eshop/Provider/FavoriteProvider.dart';
import 'package:eshop/Provider/UserProvider.dart';
import 'package:eshop/ui/widgets/AppBtn.dart';
import 'package:eshop/ui/widgets/SimBtn.dart';
import 'package:eshop/ui/widgets/Slideanimation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tuple/tuple.dart';

import '../Helper/Constant.dart';
import '../Helper/Session.dart';
import '../Helper/String.dart';
import '../Model/Section_Model.dart';
import '../ui/styles/Color.dart';
import '../ui/styles/DesignConfig.dart';
import '../ui/widgets/AppBarWidget.dart';
import 'HomePage.dart';
import 'Product_Detail.dart';
import 'Search.dart';

class ProductList extends StatefulWidget {
  final String? name, id;
  final bool? tag, fromSeller;
  final int? dis;

  const ProductList(
      {Key? key, this.id, this.name, this.tag, this.fromSeller, this.dis})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => StateProduct();
}

class StateProduct extends State<ProductList> with TickerProviderStateMixin {
  bool _isLoading = true, _isProgress = false;
  List<Product> productList = [];
  List<Product> tempList = [];
  String sortBy = 'p.id', orderBy = "DESC";
  int offset = 0;
  int total = 0;
  String? totalProduct;
  bool isLoadingmore = true;
  ScrollController controller = ScrollController();
  TextEditingController qtyController = TextEditingController();
  bool qtyChange = false;
  var filterList;
  String minPrice = "0", maxPrice = "0";
  List<String>? attnameList;
  List<String>? attsubList;
  List<String>? attListId;
  bool _isNetworkAvail = true;
  List<String> selectedId = [];
  bool _isFirstLoad = true;
  final List<int?> _selectedIndex = [];
  int _oldSelVarient = 0;
  bool? available, outOfStock;
  int? selectIndex = 0;

  String selId = "";
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  Animation? buttonSqueezeanimation;
  AnimationController? buttonController;
  bool listType = true;
  final List<TextEditingController> _controller = [];
  List<String>? tagList = [];
  ChoiceChip? tagChip, choiceChip;
  RangeValues? _currentRangeValues;
  var db = DatabaseHelper();
  AnimationController? _animationController;
  AnimationController? _animationController1;
  late StateSetter setStater;

  String query = '';

  final TextEditingController _controller1 = TextEditingController();
  bool notificationisnodata = false;

  FocusNode searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _hasSpeech = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  final SpeechToText speech = SpeechToText();

  String lastStatus = '';
  String _currentLocaleId = '';
  String lastWords = '';
  List<LocaleName> _localeNames = [];

  Future processProduct(Product? model) async {
    _selectedIndex.clear();
    if (model!.stockType == '0' || model.stockType == '1') {
      if (model.availability == '1') {
        available = true;
        outOfStock = false;
        _oldSelVarient = model.selVarient!;
      } else {
        available = false;
        outOfStock = true;
      }
    } else if (model.stockType == '') {
      available = true;
      outOfStock = false;
      _oldSelVarient = model.selVarient!;
    } else if (model.stockType == '2') {
      if (model.prVarientList![model.selVarient!].availability == '1') {
        available = true;
        outOfStock = false;
        _oldSelVarient = model.selVarient!;
      } else {
        available = false;
        outOfStock = true;
      }
    }

    List<String> selList =
        model.prVarientList![model.selVarient!].attribute_value_ids!.split(',');

    for (int i = 0; i < model.attributeList!.length; i++) {
      List<String> sinList = model.attributeList![i].id!.split(',');

      for (int j = 0; j < sinList.length; j++) {
        if (selList.contains(sinList[j])) {
          _selectedIndex.insert(i, j);
        }
      }

      if (_selectedIndex.length == i) _selectedIndex.insert(i, null);
    }
  }

  @override
  void initState() {
    super.initState();
    offset = 0;
    controller = ScrollController(keepScrollOffset: true);
    controller.addListener(_scrollListener);
    _controller1.addListener(() {
      if (_controller1.text.isEmpty) {
        setState(() {
          query = '';
          offset = 0;
          isLoadingmore = true;
          getProduct('0');
        });
      } else {
        query = _controller1.text;
        offset = 0;
        notificationisnodata = false;

        if (query.trim().isNotEmpty) {
          if (_debounce?.isActive ?? false) _debounce!.cancel();
          _debounce = Timer(const Duration(milliseconds: 500), () {
            if (query.trim().isNotEmpty) {
              isLoadingmore = true;
              offset = 0;
              getProduct('0');
            }
          });
        }
      }
      ScaffoldMessenger.of(context).clearSnackBars();
    });

    getProduct("0");

    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _animationController1 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));

    buttonController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);

    buttonSqueezeanimation = Tween(
      begin: deviceWidth! * 0.7,
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: buttonController!,
      curve: const Interval(
        0.0,
        0.150,
      ),
    ));
  }

  _scrollListener() {
    if (controller.offset >= controller.position.maxScrollExtent &&
        !controller.position.outOfRange) {
      if (mounted) {
        if (mounted) {
          setState(() {
            isLoadingmore = true;
            if (offset < total) getProduct("0");
          });
        }
      }
    }
  }

  @override
  void dispose() {
    buttonController!.dispose();
    _animationController!.dispose();
    _animationController1!.dispose();
    controller.removeListener(() {});
    _controller1.dispose();
    for (int i = 0; i < _controller.length; i++) {
      _controller[i].dispose();
    }
    super.dispose();
  }

  Future<void> _playAnimation() async {
    try {
      await buttonController!.forward();
    } on TickerCanceled {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: widget.fromSeller! ? null : getAppBar(widget.name!, context),
        // key: _scaffoldKey,
        body: _isNetworkAvail
            ? Stack(
                children: <Widget>[
                  _showForm(),
                  showCircularProgress(_isProgress, colors.primary),
                ],
              )
            : noInternet(context));
  }

  Widget noInternet(BuildContext context) {
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        noIntImage(),
        noIntText(context),
        noIntDec(context),
        AppBtn(
          title: getTranslated(context, 'TRY_AGAIN_INT_LBL'),
          btnAnim: buttonSqueezeanimation,
          btnCntrl: buttonController,
          onBtnSelected: () async {
            _playAnimation();
            Future.delayed(const Duration(seconds: 2)).then((_) async {
              _isNetworkAvail = await isNetworkAvailable();
              if (_isNetworkAvail) {
                offset = 0;
                total = 0;
                getProduct("0");
              } else {
                await buttonController!.reverse();
                if (mounted) setState(() {});
              }
            });
          },
        )
      ]),
    );
  }

  noIntBtn(BuildContext context) {
    double width = deviceWidth!;
    return Container(
        padding: const EdgeInsetsDirectional.only(bottom: 10.0, top: 50.0),
        child: Center(
            child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: colors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(80.0)),
          ),
          onPressed: () {
            Navigator.pushReplacement(
                context,
                CupertinoPageRoute(
                    builder: (BuildContext context) => super.widget));
          },
          child: Ink(
            child: Container(
              constraints: BoxConstraints(maxWidth: width / 1.2, minHeight: 45),
              alignment: Alignment.center,
              child: Text(getTranslated(context, 'TRY_AGAIN_INT_LBL')!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headline6!.copyWith(
                      color: Theme.of(context).colorScheme.white,
                      fontWeight: FontWeight.normal)),
            ),
          ),
        )));
  }

  Widget listItem(int index) {
    if (index < productList.length) {
      Product model = productList[index];

      totalProduct = model.total;

      if (_controller.length < index + 1) {
        _controller.add(TextEditingController(text: '1'));
      }

      List att = [], val = [];
      if (model.prVarientList![model.selVarient!].attr_name != null) {
        att = model.prVarientList![model.selVarient!].attr_name!.split(',');
        val = model.prVarientList![model.selVarient!].varient_value!.split(',');
      }

      double price =
          double.parse(model.prVarientList![model.selVarient!].disPrice!);
      if (price == 0) {
        price = double.parse(model.prVarientList![model.selVarient!].price!);
      }

      double off = 0;
      if (model.prVarientList![model.selVarient!].disPrice! != "0") {
        off = (double.parse(model.prVarientList![model.selVarient!].price!) -
                double.parse(model.prVarientList![model.selVarient!].disPrice!))
            .toDouble();
        off = off *
            100 /
            double.parse(model.prVarientList![model.selVarient!].price!);
      }

      return SlideAnimation(
          position: index,
          itemCount: productList.length,
          slideDirection: SlideDirection.fromBottom,
          animationController: _animationController,
          child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8),
              child: Selector<CartProvider, Tuple2<List<String?>, String?>>(
                builder: (context, data, child) {
                  if (data.item1
                      .contains(model.prVarientList![model.selVarient!].id)) {
                    _controller[index].text = data.item2.toString();
                  } else {
                    if (CUR_USERID != null) {
                      _controller[index].text =
                          model.prVarientList![model.selVarient!].cartCount!;
                    } else {
                      _controller[index].text = "1";
                    }
                  }

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Card(
                        elevation: 0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Hero(
                                    tag: "$proListHero$index${model.id}0",
                                    child: ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(10),
                                            bottomLeft: Radius.circular(10)),
                                        child: Stack(
                                          children: [
                                            FadeInImage(
                                              image: NetworkImage(model.image!),
                                              height: 125.0,
                                              width: 110.0,
                                              fit: extendImg
                                                  ? BoxFit.fill
                                                  : BoxFit.contain,
                                              imageErrorBuilder: (context,
                                                      error, stackTrace) =>
                                                  erroWidget(125),
                                              placeholder: placeHolder(125),
                                            ),
                                            Positioned.fill(
                                                child: model.availability == "0"
                                                    ? Container(
                                                        height: 55,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .white70,
                                                        padding:
                                                            const EdgeInsets
                                                                .all(2),
                                                        child: Center(
                                                          child: Text(
                                                            getTranslated(
                                                                context,
                                                                'OUT_OF_STOCK_LBL')!,
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .caption!
                                                                .copyWith(
                                                                  color: Colors
                                                                      .red,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                      )
                                                    : Container()),
                                            off != 0
                                                ? Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: colors.red,
                                                    ),
                                                    margin:
                                                        const EdgeInsets.all(5),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              5.0),
                                                      child: Text(
                                                        "${off.toStringAsFixed(2)}%",
                                                        style: const TextStyle(
                                                            color: colors
                                                                .whiteTemp,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 9),
                                                      ),
                                                    ),
                                                  )
                                                : Container()
                                          ],
                                        ))),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          model.name!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .subtitle1!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .lightBlack),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        model.prVarientList![model.selVarient!]
                                                        .attr_name !=
                                                    null &&
                                                model
                                                    .prVarientList![
                                                        model.selVarient!]
                                                    .attr_name!
                                                    .isNotEmpty
                                            ? ListView.builder(
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                shrinkWrap: true,
                                                itemCount: att.length >= 2
                                                    ? 2
                                                    : att.length,
                                                itemBuilder: (context, index) {
                                                  return Row(children: [
                                                    Flexible(
                                                      child: Text(
                                                        att[index].trim() + ":",
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .subtitle2!
                                                            .copyWith(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .lightBlack),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .only(start: 5.0),
                                                      child: Text(
                                                        val[index],
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .subtitle2!
                                                            .copyWith(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .lightBlack,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                      ),
                                                    )
                                                  ]);
                                                })
                                            : Container(),
                                        model.noOfRating! != "0"
                                            ? Row(
                                                children: [
                                                  RatingBarIndicator(
                                                    rating: double.parse(
                                                        model.rating!),
                                                    itemBuilder:
                                                        (context, index) =>
                                                            const Icon(
                                                      Icons.star_rate_rounded,
                                                      color: Colors.amber,
                                                    ),
                                                    unratedColor: Colors.grey
                                                        .withOpacity(0.5),
                                                    itemCount: 5,
                                                    itemSize: 18.0,
                                                    direction: Axis.horizontal,
                                                  ),
                                                  Text(
                                                    " (${model.noOfRating!})",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .overline,
                                                  )
                                                ],
                                              )
                                            : Container(),
                                        Row(
                                          children: <Widget>[
                                            Text(
                                                '${getPriceFormat(context, price)!} ',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .subtitle2!
                                                    .copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .fontColor,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                            Text(
                                              double.parse(model
                                                          .prVarientList![
                                                              model.selVarient!]
                                                          .disPrice!) !=
                                                      0
                                                  ? getPriceFormat(
                                                      context,
                                                      double.parse(model
                                                          .prVarientList![
                                                              model.selVarient!]
                                                          .price!))!
                                                  : "",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .overline!
                                                  .copyWith(
                                                      decoration: TextDecoration
                                                          .lineThrough,
                                                      letterSpacing: 0),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ]),
                          onTap: () {
                            Product model = productList[index];
                            currentHero = proListHero;
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => ProductDetail(
                                        model: model,
                                        index: index,
                                        secPos: 0,
                                        list: true,
                                      )),
                            );
                          },
                        ),
                      ),
                      Positioned.directional(
                        textDirection: Directionality.of(context),
                        bottom: -15,
                        end: 65,
                        child: InkWell(
                          onTap: () async {
                            if (_isProgress == false) {
                              await processProduct(model);
                              showDialog(
                                  context: context,
                                  builder: (ctx) => StatefulBuilder(
                                        builder: (cont, setState) =>
                                            AlertDialog(
                                          title: Text(
                                            model.name!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .subtitle1!
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .lightBlack),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          content: SizedBox(
                                            height: 300,
                                            width: 200,
                                            child: Card(
                                              elevation: 0,
                                              // color: Colors.red,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ListView.builder(
                                                    shrinkWrap: true,
                                                    // physics:
                                                    //     const NeverScrollableScrollPhysics(),
                                                    itemCount: model
                                                        .attributeList!.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      List<Widget?> chips = [];
                                                      List<String> att = model
                                                          .attributeList![index]
                                                          .value!
                                                          .split(',');
                                                      List<String> attId = model
                                                          .attributeList![index]
                                                          .id!
                                                          .split(',');
                                                      List<String> attSType =
                                                          model
                                                              .attributeList![
                                                                  index]
                                                              .sType!
                                                              .split(',');

                                                      List<String> attSValue =
                                                          model
                                                              .attributeList![
                                                                  index]
                                                              .sValue!
                                                              .split(',');

                                                      int? varSelected;

                                                      List<String> wholeAtt =
                                                          model.attrIds!
                                                              .split(',');
                                                      for (int i = 0;
                                                          i < att.length;
                                                          i++) {
                                                        Widget itemLabel;
                                                        if (attSType[i] ==
                                                            '1') {
                                                          String clr =
                                                              (attSValue[i]
                                                                  .substring(
                                                                      1));

                                                          String color =
                                                              '0xff$clr';

                                                          itemLabel = Container(
                                                            width: 25,
                                                            decoration: BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: Color(
                                                                    int.parse(
                                                                        color))),
                                                          );
                                                        } else if (attSType[
                                                                i] ==
                                                            '2') {
                                                          itemLabel = ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10.0),
                                                              child: Image.network(
                                                                  attSValue[i],
                                                                  width: 80,
                                                                  height: 80,
                                                                  errorBuilder: (context,
                                                                          error,
                                                                          stackTrace) =>
                                                                      erroWidget(
                                                                          80)));
                                                        } else {
                                                          itemLabel = Text(
                                                              att[i],
                                                              style: TextStyle(
                                                                  color: _selectedIndex[
                                                                              index] ==
                                                                          (i)
                                                                      ? Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .white
                                                                      : Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .fontColor));
                                                        }

                                                        if (_selectedIndex[
                                                                    index] !=
                                                                null &&
                                                            wholeAtt.contains(
                                                                attId[i])) {
                                                          choiceChip =
                                                              ChoiceChip(
                                                            selected: _selectedIndex
                                                                        .length >
                                                                    index
                                                                ? _selectedIndex[
                                                                        index] ==
                                                                    i
                                                                : false,
                                                            label: itemLabel,
                                                            selectedColor:
                                                                colors.primary,
                                                            backgroundColor:
                                                                Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .white,
                                                            labelPadding:
                                                                const EdgeInsets
                                                                    .all(0),
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                      attSType[i] ==
                                                                              '1'
                                                                          ? 100
                                                                          : 10),
                                                              side: BorderSide(
                                                                  color: _selectedIndex[
                                                                              index] ==
                                                                          (i)
                                                                      ? colors
                                                                          .primary
                                                                      : colors
                                                                          .black12,
                                                                  width: 1.5),
                                                            ),
                                                            onSelected: att
                                                                        .length ==
                                                                    1
                                                                ? null
                                                                : (bool
                                                                    selected) async {
                                                                    if (selected) {
                                                                      if (mounted) {
                                                                        setState(
                                                                            () {
                                                                          model.selVarient =
                                                                              _oldSelVarient;

                                                                          available =
                                                                              false;
                                                                          _selectedIndex[index] = selected
                                                                              ? i
                                                                              : null;
                                                                          List<int>
                                                                              selectedId =
                                                                              []; //list where user choosen item id is stored
                                                                          List<bool>
                                                                              check =
                                                                              [];
                                                                          for (int i = 0;
                                                                              i < model.attributeList!.length;
                                                                              i++) {
                                                                            List<String>
                                                                                attId =
                                                                                model.attributeList![i].id!.split(',');

                                                                            if (_selectedIndex[i] !=
                                                                                null) {
                                                                              selectedId.add(int.parse(attId[_selectedIndex[i]!]));
                                                                            }
                                                                          }
                                                                          check
                                                                              .clear();
                                                                          late List<String>
                                                                              sinId;
                                                                          findMatch:
                                                                          for (int i = 0;
                                                                              i < model.prVarientList!.length;
                                                                              i++) {
                                                                            sinId =
                                                                                model.prVarientList![i].attribute_value_ids!.split(',');

                                                                            for (int j = 0;
                                                                                j < selectedId.length;
                                                                                j++) {
                                                                              if (sinId.contains(selectedId[j].toString())) {
                                                                                check.add(true);

                                                                                if (selectedId.length == sinId.length && check.length == selectedId.length) {
                                                                                  varSelected = i;
                                                                                  selectIndex = i;
                                                                                  break findMatch;
                                                                                }
                                                                              } else {
                                                                                check.clear();
                                                                                selectIndex = null;
                                                                                break;
                                                                              }
                                                                            }
                                                                          }

                                                                          if (selectedId.length == sinId.length &&
                                                                              check.length == selectedId.length) {
                                                                            if (model.stockType == '0' ||
                                                                                model.stockType == '1') {
                                                                              if (model.availability == '1') {
                                                                                available = true;
                                                                                outOfStock = false;
                                                                                _oldSelVarient = varSelected!;
                                                                              } else {
                                                                                available = false;
                                                                                outOfStock = true;
                                                                              }
                                                                            } else if (model.stockType == '') {
                                                                              available = true;
                                                                              outOfStock = false;
                                                                              _oldSelVarient = varSelected!;
                                                                            } else if (model.stockType == '2') {
                                                                              if (model.prVarientList![varSelected!].availability == '1') {
                                                                                available = true;
                                                                                outOfStock = false;
                                                                                _oldSelVarient = varSelected!;
                                                                              } else {
                                                                                available = false;
                                                                                outOfStock = true;
                                                                              }
                                                                            }
                                                                          } else {
                                                                            available =
                                                                                false;
                                                                            outOfStock =
                                                                                false;
                                                                          }
                                                                        });
                                                                      } else {}
                                                                    } else {
                                                                      null;
                                                                    }
                                                                    if (available!) {
                                                                      if (CUR_USERID !=
                                                                          null) {
                                                                        if (model.prVarientList![_oldSelVarient].cartCount! !=
                                                                            "0") {
                                                                          qtyController.text = model
                                                                              .prVarientList![_oldSelVarient]
                                                                              .cartCount!;
                                                                          qtyChange =
                                                                              true;
                                                                        } else {
                                                                          qtyController.text = model
                                                                              .minOrderQuntity
                                                                              .toString();
                                                                          qtyChange =
                                                                              true;
                                                                        }
                                                                      } else {
                                                                        String qty = (await db.checkCartItemExists(
                                                                            model.id!,
                                                                            model.prVarientList![_oldSelVarient].id!))!;
                                                                        if (qty ==
                                                                            "0") {
                                                                          qtyController.text = model
                                                                              .minOrderQuntity
                                                                              .toString();
                                                                          qtyChange =
                                                                              true;
                                                                        } else {
                                                                          model.prVarientList![_oldSelVarient].cartCount =
                                                                              qty;
                                                                          qtyController.text =
                                                                              qty;
                                                                          qtyChange =
                                                                              true;
                                                                        }
                                                                      }
                                                                    }
                                                                  },
                                                          );
                                                          chips.add(choiceChip);
                                                        }
                                                      }

                                                      String value = _selectedIndex[
                                                                      index] !=
                                                                  null &&
                                                              _selectedIndex[
                                                                      index]! <=
                                                                  att.length
                                                          ? att[_selectedIndex[
                                                              index]!]
                                                          : getTranslated(
                                                                  context,
                                                                  'VAR_SEL')!
                                                              .substring(
                                                                  2,
                                                                  getTranslated(
                                                                          context,
                                                                          'VAR_SEL')!
                                                                      .length);
                                                      return chips.isNotEmpty
                                                          ? Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: <Widget>[
                                                                  Row(
                                                                    children: [
                                                                      Text(
                                                                        "${model.attributeList![index].name!} : ",
                                                                        style: Theme.of(context)
                                                                            .textTheme
                                                                            .subtitle2!
                                                                            .copyWith(
                                                                                color: Theme.of(context).colorScheme.fontColor,
                                                                                fontWeight: FontWeight.bold),
                                                                      ),
                                                                      Text(
                                                                        value,
                                                                        style: Theme.of(context)
                                                                            .textTheme
                                                                            .subtitle2!
                                                                            .copyWith(
                                                                              color: Theme.of(context).colorScheme.fontColor,
                                                                            ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Text(
                                                                    getPriceFormat(
                                                                        context,
                                                                        // double.parse(model.prVarientList![_oldSelVarient].price!) -
                                                                        double.parse(model
                                                                            .prVarientList![_oldSelVarient]
                                                                            .disPrice!))!,
                                                                  ),
                                                                  Wrap(
                                                                    children: chips.map<
                                                                            Widget>(
                                                                        (Widget?
                                                                            chip) {
                                                                      return Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            2.0),
                                                                        child:
                                                                            chip,
                                                                      );
                                                                    }).toList(),
                                                                  ),
                                                                ],
                                                              ),
                                                            )
                                                          : Container();
                                                    },
                                                  ),
                                                  TextField(
                                                    controller:
                                                        _controller[index]
                                                          ..text = '1',
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .fontColor,
                                                    ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                      label: Text('Quantity'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          actions: <Widget>[
                                            ElevatedButton(
                                              onPressed: () {
                                                addToCart(
                                                    index,
                                                    (int.parse(
                                                            _controller[index]
                                                                .text))
                                                        .toString(),
                                                    1);
                                                Navigator.of(ctx).pop();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      colors.primary),
                                              child: Text(
                                                "Add",
                                                style: TextStyle(
                                                  color: Theme.of(ctx)
                                                      .colorScheme
                                                      .fontColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ));
                            }
                          },
                          child: Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Add',
                                style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.directional(
                          textDirection: Directionality.of(context),
                          bottom: -15,
                          end: 15,
                          child: Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: model.isFavLoading!
                                  ? const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: colors.primary,
                                            strokeWidth: 0.7,
                                          )),
                                    )
                                  : Selector<FavoriteProvider, List<String?>>(
                                      builder: (context, data, child) {
                                        return InkWell(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              !data.contains(model.id)
                                                  ? Icons.favorite_border
                                                  : Icons.favorite,
                                              size: 20,
                                            ),
                                          ),
                                          onTap: () {
                                            if (CUR_USERID != null) {
                                              !data.contains(model.id)
                                                  ? _setFav(-1, model)
                                                  : _removeFav(-1, model);
                                            } else {
                                              if (!data.contains(model.id)) {
                                                model.isFavLoading = true;
                                                model.isFav = "1";
                                                context
                                                    .read<FavoriteProvider>()
                                                    .addFavItem(model);
                                                db.addAndRemoveFav(
                                                    model.id!, true);
                                                model.isFavLoading = false;
                                              } else {
                                                model.isFavLoading = true;
                                                model.isFav = "0";
                                                context
                                                    .read<FavoriteProvider>()
                                                    .removeFavItem(model
                                                        .prVarientList![0].id!);
                                                db.addAndRemoveFav(
                                                    model.id!, false);
                                                model.isFavLoading = false;
                                              }
                                              setState(() {});
                                            }
                                          },
                                        );
                                      },
                                      selector: (_, provider) =>
                                          provider.favIdList,
                                    )))
                    ],
                  );
                },
                selector: (_, provider) => Tuple2(provider.cartIdList,
                    provider.qtyList(model.id!, model.prVarientList![0].id!)),
              )));
    } else {
      return Container();
    }
  }

  _setFav(int index, Product model) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        if (mounted) {
          setState(() {
            index == -1
                ? model.isFavLoading = true
                : productList[index].isFavLoading = true;
          });
        }

        var parameter = {USER_ID: CUR_USERID, PRODUCT_ID: model.id};
        apiBaseHelper.postAPICall(setFavoriteApi, parameter).then((getdata) {
          bool error = getdata["error"];
          String? msg = getdata["message"];
          if (!error) {
            index == -1 ? model.isFav = "1" : productList[index].isFav = "1";

            context.read<FavoriteProvider>().addFavItem(model);
          } else {
            setSnackbar(msg!, context);
          }

          if (mounted) {
            setState(() {
              index == -1
                  ? model.isFavLoading = false
                  : productList[index].isFavLoading = false;
            });
          }
        }, onError: (error) {
          setSnackbar(error.toString(), context);
        });
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  _removeFav(int index, Product model) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        if (mounted) {
          setState(() {
            index == -1
                ? model.isFavLoading = true
                : productList[index].isFavLoading = true;
          });
        }

        var parameter = {USER_ID: CUR_USERID, PRODUCT_ID: model.id};
        apiBaseHelper.postAPICall(removeFavApi, parameter).then((getdata) {
          bool error = getdata["error"];
          String? msg = getdata["message"];
          if (!error) {
            index == -1 ? model.isFav = "0" : productList[index].isFav = "0";
            context
                .read<FavoriteProvider>()
                .removeFavItem(model.prVarientList![0].id!);
          } else {
            setSnackbar(msg!, context);
          }

          if (mounted) {
            setState(() {
              index == -1
                  ? model.isFavLoading = false
                  : productList[index].isFavLoading = false;
            });
          }
        }, onError: (error) {
          setSnackbar(error.toString(), context);
        });
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  removeFromCart(int index) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      if (CUR_USERID != null) {
        if (mounted) {
          setState(() {
            _isProgress = true;
          });
        }

        int qty;

        qty = (int.parse(_controller[index].text) -
            int.parse(productList[index].qtyStepSize!));

        if (qty < productList[index].minOrderQuntity!) {
          qty = 0;
        }

        var parameter = {
          PRODUCT_VARIENT_ID: productList[index]
              .prVarientList![productList[index].selVarient!]
              .id,
          USER_ID: CUR_USERID,
          QTY: qty.toString()
        };

        apiBaseHelper.postAPICall(manageCartApi, parameter).then((getdata) {
          bool error = getdata["error"];
          String? msg = getdata["message"];
          if (!error) {
            var data = getdata["data"];

            String? qty = data['total_quantity'];

            context.read<UserProvider>().setCartCount(data['cart_count']);
            productList[index]
                .prVarientList![productList[index].selVarient!]
                .cartCount = qty.toString();

            var cart = getdata["cart"];
            List<SectionModel> cartList = (cart as List)
                .map((cart) => SectionModel.fromCart(cart))
                .toList();
            context.read<CartProvider>().setCartlist(cartList);
          } else {
            setSnackbar(msg!, context);
          }

          if (mounted) {
            setState(() {
              _isProgress = false;
            });
          }
        }, onError: (error) {
          setSnackbar(error.toString(), context);
          setState(() {
            _isProgress = false;
          });
        });
      } else {
        setState(() {
          _isProgress = true;
        });

        int qty;

        qty = (int.parse(_controller[index].text) -
            int.parse(productList[index].qtyStepSize!));

        if (qty < productList[index].minOrderQuntity!) {
          qty = 0;
          db.removeCart(
              productList[index]
                  .prVarientList![productList[index].selVarient!]
                  .id!,
              productList[index].id!,
              context);
          context.read<CartProvider>().removeCartItem(productList[index]
              .prVarientList![productList[index].selVarient!]
              .id!);
        } else {
          context.read<CartProvider>().updateCartItem(
              productList[index].id!,
              qty.toString(),
              productList[index].selVarient!,
              productList[index]
                  .prVarientList![productList[index].selVarient!]
                  .id!);
          db.updateCart(
              productList[index].id!,
              productList[index]
                  .prVarientList![productList[index].selVarient!]
                  .id!,
              qty.toString());
        }
        setState(() {
          _isProgress = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  Future getProduct(String top) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        if (isLoadingmore) {
          if (mounted) {
            setState(() {
              isLoadingmore = false;
              if (_controller1.hasListeners && _controller1.text.isNotEmpty) {
                _isLoading = true;
              }
            });
          }

          var parameter = {
            SEARCH: query.trim(),
            LIMIT: perPage.toString(),
            OFFSET: offset.toString(),
            TOP_RETAED: top,
            CATID: widget.id
          };

          if (CUR_USERID != null) parameter[USER_ID] = CUR_USERID!;
          if (selId != "") {
            parameter[ATTRIBUTE_VALUE_ID] = selId;
          }
          if (widget.tag!) parameter[TAG] = widget.name!;
          if (widget.fromSeller!) {
            parameter["seller_id"] = widget.id!;
          } else {
            parameter[CATID] = widget.id ?? '';
          }

          if (widget.dis != null) {
            parameter[DISCOUNT] = widget.dis.toString();
          } else {
            parameter[SORT] = sortBy;
            parameter[ORDER] = orderBy;
          }

          if (_currentRangeValues != null &&
              _currentRangeValues!.start.round().toString() != "0") {
            parameter[MINPRICE] = _currentRangeValues!.start.round().toString();
          }

          if (_currentRangeValues != null &&
              _currentRangeValues!.end.round().toString() != "0") {
            parameter[MAXPRICE] = _currentRangeValues!.end.round().toString();
          }

          apiBaseHelper.postAPICall(getProductApi, parameter).then((getdata) {
            bool error = getdata["error"];
            String? msg = getdata["message"];

            if (_isFirstLoad) {
              filterList = getdata["filters"];

              minPrice = getdata[MINPRICE].toString();
              maxPrice = getdata[MAXPRICE].toString();

              _isFirstLoad = false;
            }

            Map<String, dynamic> tempData = getdata;

            String? search = getdata['search'];

            _isLoading = false;
            if (offset == 0) notificationisnodata = error;

            if (!error) {
              total = int.parse(getdata["total"]);
              if (mounted) {
                Future.delayed(
                    Duration.zero,
                    () => setState(() {
                          if ((offset) < total) {
                            List mainlist = getdata['data'];

                            if (mainlist.isNotEmpty) {
                              List<Product> items = [];
                              List<Product> allitems = [];

                              items.addAll(mainlist
                                  .map((data) => Product.fromJson(data))
                                  .toList());

                              allitems.addAll(items);

                              getAvailVarient(allitems);
                            }
                          } else {
                            if (msg != "Products Not Found !") {
                              notificationisnodata = true;
                            }
                            isLoadingmore = false;
                          }
                        }));
              }
            } else {
              if (msg != "Products Not Found !") {
                notificationisnodata = true;
              }
              isLoadingmore = false;
              if (mounted) setState(() {});
            }
            setState(() {
              _isLoading = false;
            });
          }, onError: (error) {
            setSnackbar(error.toString(), context);
          });
        }
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
        if (mounted) {
          setState(() {
            isLoadingmore = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  void getAvailVarient(List<Product> tempList) {
    for (int j = 0; j < tempList.length; j++) {
      if (tempList[j].stockType == "2") {
        for (int i = 0; i < tempList[j].prVarientList!.length; i++) {
          if (tempList[j].prVarientList![i].availability == "1") {
            tempList[j].selVarient = i;

            break;
          }
        }
      }
    }
    if (offset == 0) {
      productList = [];
    }

    if (offset == 0 && buildResult) {
      Product element = Product(
          name: 'Search Result for "$query"',
          image: "",
          catName: "All Categories",
          history: false);
      productList.insert(0, element);
    }

    productList.addAll(tempList);

    isLoadingmore = true;
    offset = offset + perPage;
  }

  Widget productItem(int index, bool pad) {
    if (index < productList.length) {
      Product model = productList[index];

      totalProduct = model.total;

      if (_controller.length < index + 1) {
        _controller.add(TextEditingController());
      }

      double price =
          double.parse(model.prVarientList![_oldSelVarient].disPrice!);
      if (price == 0) {
        price = double.parse(model.prVarientList![_oldSelVarient].price!);
      }

      double off = 0;
      if (model.prVarientList![_oldSelVarient].disPrice! != "0") {
        off = (double.parse(model.prVarientList![_oldSelVarient].price!) -
                double.parse(model.prVarientList![_oldSelVarient].disPrice!))
            .toDouble();
        off = off *
            100 /
            double.parse(model.prVarientList![_oldSelVarient].price!);
      }

      if (_controller.length < index + 1) {
        _controller.add(TextEditingController());
      }

      _controller[index].text = model.prVarientList![_oldSelVarient].cartCount!;

      List att = [], val = [];
      if (model.prVarientList![_oldSelVarient].attr_name != null) {
        att = model.prVarientList![_oldSelVarient].attr_name!.split(',');
        val = model.prVarientList![_oldSelVarient].varient_value!.split(',');
      }
      double width = deviceWidth! * 0.5;

      return SlideAnimation(
          position: index,
          itemCount: productList.length,
          slideDirection: SlideDirection.fromBottom,
          animationController: _animationController1,
          child: Selector<CartProvider, Tuple2<List<String?>, String?>>(
            builder: (context, data, child) {
              if (data.item1
                  .contains(model.prVarientList![model.selVarient!].id)) {
                _controller[index].text = data.item2.toString();
              } else {
                if (CUR_USERID != null) {
                  _controller[index].text =
                      model.prVarientList![model.selVarient!].cartCount!;
                } else {
                  _controller[index].text = "1";
                }
              }

              return InkWell(
                child: Card(
                  elevation: 0.2,
                  margin: EdgeInsetsDirectional.only(
                      bottom: 10, end: 10, start: pad ? 10 : 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(5),
                                    topRight: Radius.circular(5)),
                                child: Hero(
                                  tag: "$proListHero$index${model.id}0",
                                  child: FadeInImage(
                                    fadeInDuration:
                                        const Duration(milliseconds: 150),
                                    image: NetworkImage(model.image!),
                                    height: double.maxFinite,
                                    width: double.maxFinite,
                                    fit: extendImg
                                        ? BoxFit.fill
                                        : BoxFit.contain,
                                    placeholder: placeHolder(width),
                                    imageErrorBuilder:
                                        (context, error, stackTrace) =>
                                            erroWidget(width),
                                  ),
                                )),
                            Positioned.fill(
                                child: model.availability == "0"
                                    ? Container(
                                        height: 55,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .white70,
                                        // width: double.maxFinite,
                                        padding: const EdgeInsets.all(2),
                                        child: Center(
                                          child: Text(
                                            getTranslated(
                                                context, 'OUT_OF_STOCK_LBL')!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .caption!
                                                .copyWith(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      )
                                    : Container()),
                            off != 0
                                ? Align(
                                    alignment: Alignment.topLeft,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: colors.red,
                                      ),
                                      margin: const EdgeInsets.all(5),
                                      child: Padding(
                                        padding: const EdgeInsets.all(5.0),
                                        child: Text(
                                          "${off.toStringAsFixed(2)}%",
                                          style: const TextStyle(
                                              color: colors.whiteTemp,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(),
                            const Divider(
                              height: 1,
                            ),
                            Positioned.directional(
                              textDirection: Directionality.of(context),
                              end: 0,
                              // bottom: -18,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  model.availability == "0" && !cartBtnList
                                      ? Container()
                                      : _controller[index].text == "0"
                                          ? InkWell(
                                              onTap: () {
                                                if (_isProgress == false) {
                                                  addToCart(
                                                      index,
                                                      (int.parse(_controller[
                                                                      index]
                                                                  .text) +
                                                              int.parse(model
                                                                  .qtyStepSize!))
                                                          .toString(),
                                                      1);
                                                }
                                              },
                                              child: Card(
                                                elevation: 1,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                ),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Icon(
                                                    Icons
                                                        .shopping_cart_outlined,
                                                    size: 15,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .only(
                                                      start: 3.0,
                                                      bottom: 5,
                                                      top: 3),
                                              child: Row(
                                                children: <Widget>[
                                                  InkWell(
                                                    child: Card(
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(50),
                                                      ),
                                                      child: const Padding(
                                                        padding:
                                                            EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.remove,
                                                          size: 15,
                                                        ),
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      if (_isProgress ==
                                                              false &&
                                                          (int.parse(
                                                                  _controller[
                                                                          index]
                                                                      .text) >
                                                              0)) {
                                                        removeFromCart(index);
                                                      }
                                                    },
                                                  ),
                                                  Container(
                                                    width: 37,
                                                    height: 20,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .white70,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5),
                                                    ),
                                                    child: Stack(
                                                      children: [
                                                        Selector<
                                                            CartProvider,
                                                            Tuple2<
                                                                List<String?>,
                                                                String?>>(
                                                          builder: (context,
                                                              data, child) {
                                                            return TextField(
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              readOnly: true,
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .fontColor),
                                                              controller:
                                                                  _controller[
                                                                      index],
                                                              decoration:
                                                                  const InputDecoration(
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                              ),
                                                            );
                                                          },
                                                          selector: (_, provider) => Tuple2(
                                                              provider
                                                                  .cartIdList,
                                                              provider.qtyList(
                                                                  model.id!,
                                                                  model
                                                                      .prVarientList![
                                                                          0]
                                                                      .id!)),
                                                        ),
                                                        PopupMenuButton<String>(
                                                          tooltip: '',
                                                          icon: const Icon(
                                                            Icons
                                                                .arrow_drop_down,
                                                            size: 0,
                                                          ),
                                                          onSelected:
                                                              (String value) {
                                                            if (_isProgress ==
                                                                false) {
                                                              addToCart(index,
                                                                  value, 2);
                                                            }
                                                          },
                                                          itemBuilder:
                                                              (BuildContext
                                                                  context) {
                                                            return model
                                                                .itemsCounter!
                                                                .map<
                                                                    PopupMenuItem<
                                                                        String>>((String
                                                                    value) {
                                                              return PopupMenuItem(
                                                                  value: value,
                                                                  child: Text(
                                                                      value,
                                                                      style: TextStyle(
                                                                          color: Theme.of(context)
                                                                              .colorScheme
                                                                              .fontColor)));
                                                            }).toList();
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ), // ),

                                                  InkWell(
                                                    child: Card(
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(50),
                                                      ),
                                                      child: const Padding(
                                                        padding:
                                                            EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.add,
                                                          size: 15,
                                                        ),
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      if (_isProgress ==
                                                          false) {
                                                        addToCart(
                                                            index,
                                                            (int.parse(_controller[
                                                                            index]
                                                                        .text) +
                                                                    int.parse(model
                                                                        .qtyStepSize!))
                                                                .toString(),
                                                            2);
                                                      }
                                                    },
                                                  )
                                                ],
                                              ),
                                            ),
                                  Card(
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: model.isFavLoading!
                                          ? const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: SizedBox(
                                                  height: 15,
                                                  width: 15,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: colors.primary,
                                                    strokeWidth: 0.7,
                                                  )),
                                            )
                                          : Selector<FavoriteProvider,
                                              List<String?>>(
                                              builder: (context, data, child) {
                                                return InkWell(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Icon(
                                                      !data.contains(model.id)
                                                          ? Icons
                                                              .favorite_border
                                                          : Icons.favorite,
                                                      size: 15,
                                                    ),
                                                  ),
                                                  onTap: () {
                                                    if (CUR_USERID != null) {
                                                      !data.contains(model.id)
                                                          ? _setFav(-1, model)
                                                          : _removeFav(
                                                              -1, model);
                                                    } else {
                                                      if (!data
                                                          .contains(model.id)) {
                                                        model.isFavLoading =
                                                            true;
                                                        model.isFav = "1";
                                                        context
                                                            .read<
                                                                FavoriteProvider>()
                                                            .addFavItem(model);
                                                        db.addAndRemoveFav(
                                                            model.id!, true);
                                                        model.isFavLoading =
                                                            false;
                                                      } else {
                                                        model.isFavLoading =
                                                            true;
                                                        model.isFav = "0";
                                                        context
                                                            .read<
                                                                FavoriteProvider>()
                                                            .removeFavItem(model
                                                                .prVarientList![
                                                                    0]
                                                                .id!);
                                                        db.addAndRemoveFav(
                                                            model.id!, false);
                                                        model.isFavLoading =
                                                            false;
                                                      }
                                                      setState(() {});
                                                    }
                                                  },
                                                );
                                              },
                                              selector: (_, provider) =>
                                                  provider.favIdList,
                                            )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: double.parse(model.rating!),
                            itemBuilder: (context, index) => const Icon(
                              Icons.star_rate_rounded,
                              color: Colors.amber,
                              //color: colors.primary,
                            ),
                            unratedColor: Colors.grey.withOpacity(0.5),
                            itemCount: 5,
                            itemSize: 12.0,
                            direction: Axis.horizontal,
                            itemPadding: const EdgeInsets.all(0),
                          ),
                          Text(
                            " (${model.noOfRating!})",
                            style: Theme.of(context).textTheme.overline,
                          )
                        ],
                      ),
                      Row(
                        children: [
                          Text('${getPriceFormat(context, price)!} ',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.fontColor,
                                  fontWeight: FontWeight.bold)),
                          double.parse(model.prVarientList![model.selVarient!]
                                      .disPrice!) !=
                                  0
                              ? Flexible(
                                  child: Row(
                                    children: <Widget>[
                                      Flexible(
                                        child: Text(
                                          double.parse(model
                                                      .prVarientList![
                                                          model.selVarient!]
                                                      .disPrice!) !=
                                                  0
                                              ? getPriceFormat(
                                                  context,
                                                  double.parse(model
                                                      .prVarientList![
                                                          model.selVarient!]
                                                      .price!))!
                                              : "",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .overline!
                                              .copyWith(
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  letterSpacing: 0),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container()
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: model.prVarientList![model.selVarient!]
                                              .attr_name !=
                                          null &&
                                      model.prVarientList![model.selVarient!]
                                          .attr_name!.isNotEmpty
                                  ? ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 5.0),
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      itemCount:
                                          att.length >= 2 ? 2 : att.length,
                                      itemBuilder: (context, index) {
                                        return Row(children: [
                                          Flexible(
                                            child: Text(
                                              att[index].trim() + ":",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .caption!
                                                  .copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .lightBlack),
                                            ),
                                          ),
                                          Flexible(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .only(start: 5.0),
                                              child: Text(
                                                val[index],
                                                maxLines: 1,
                                                overflow: TextOverflow.visible,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .caption!
                                                    .copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .lightBlack,
                                                        fontWeight:
                                                            FontWeight.bold),
                                              ),
                                            ),
                                          )
                                        ]);
                                      })
                                  : Container(),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            start: 5.0, bottom: 5),
                        child: Text(
                          model.name!,
                          style: Theme.of(context)
                              .textTheme
                              .subtitle1!
                              .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.lightBlack),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  //),
                ),
                onTap: () {
                  Product model = productList[index];
                  currentHero = proListHero;
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                        pageBuilder: (_, __, ___) => ProductDetail(
                              model: model,
                              index: index,
                              secPos: 0,
                              list: true,
                            )),
                  );
                },
              );
            },
            selector: (_, provider) => Tuple2(provider.cartIdList,
                provider.qtyList(model.id!, model.prVarientList![0].id!)),
          ));
    } else {
      return Container();
    }
  }

  void sortDialog() {
    showModalBottomSheet(
      backgroundColor: Theme.of(context).colorScheme.white,
      context: context,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25.0),
          topRight: Radius.circular(25.0),
        ),
      ),
      builder: (builder) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                            top: 19.0, bottom: 16.0),
                        child: Text(
                          getTranslated(context, 'SORT_BY')!,
                          style: Theme.of(context)
                              .textTheme
                              .headline6!
                              .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.fontColor),
                        )),
                  ),
                  InkWell(
                    onTap: () {
                      sortBy = '';
                      orderBy = 'DESC';
                      if (mounted) {
                        setState(() {
                          _isLoading = true;
                          total = 0;
                          offset = 0;
                          productList.clear();
                        });
                      }
                      getProduct("1");
                      Navigator.pop(context, 'option 1');
                    },
                    child: Container(
                      width: deviceWidth,
                      color: sortBy == ''
                          ? colors.primary
                          : Theme.of(context).colorScheme.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      child: Text(getTranslated(context, 'TOP_RATED')!,
                          style: Theme.of(context)
                              .textTheme
                              .subtitle1!
                              .copyWith(
                                  color: sortBy == ''
                                      ? Theme.of(context).colorScheme.white
                                      : Theme.of(context)
                                          .colorScheme
                                          .fontColor)),
                    ),
                  ),
                  InkWell(
                      child: Container(
                          width: deviceWidth,
                          color: sortBy == 'p.date_added' && orderBy == 'DESC'
                              ? colors.primary
                              : Theme.of(context).colorScheme.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Text(getTranslated(context, 'F_NEWEST')!,
                              style: Theme.of(context)
                                  .textTheme
                                  .subtitle1!
                                  .copyWith(
                                      color: sortBy == 'p.date_added' &&
                                              orderBy == 'DESC'
                                          ? Theme.of(context).colorScheme.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .fontColor))),
                      onTap: () {
                        sortBy = 'p.date_added';
                        orderBy = 'DESC';
                        if (mounted) {
                          setState(() {
                            _isLoading = true;
                            total = 0;
                            offset = 0;
                            productList.clear();
                          });
                        }
                        getProduct("0");
                        Navigator.pop(context, 'option 1');
                      }),
                  InkWell(
                      child: Container(
                          width: deviceWidth,
                          color: sortBy == 'p.date_added' && orderBy == 'ASC'
                              ? colors.primary
                              : Theme.of(context).colorScheme.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Text(
                            getTranslated(context, 'F_OLDEST')!,
                            style: Theme.of(context)
                                .textTheme
                                .subtitle1!
                                .copyWith(
                                    color: sortBy == 'p.date_added' &&
                                            orderBy == 'ASC'
                                        ? Theme.of(context).colorScheme.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .fontColor),
                          )),
                      onTap: () {
                        sortBy = 'p.date_added';
                        orderBy = 'ASC';
                        if (mounted) {
                          setState(() {
                            _isLoading = true;
                            total = 0;
                            offset = 0;
                            productList.clear();
                          });
                        }
                        getProduct("0");
                        Navigator.pop(context, 'option 2');
                      }),
                  InkWell(
                      child: Container(
                          width: deviceWidth,
                          color: sortBy == 'pv.price' && orderBy == 'ASC'
                              ? colors.primary
                              : Theme.of(context).colorScheme.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Text(
                            getTranslated(context, 'F_LOW')!,
                            style: Theme.of(context)
                                .textTheme
                                .subtitle1!
                                .copyWith(
                                    color: sortBy == 'pv.price' &&
                                            orderBy == 'ASC'
                                        ? Theme.of(context).colorScheme.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .fontColor),
                          )),
                      onTap: () {
                        sortBy = 'pv.price';
                        orderBy = 'ASC';
                        if (mounted) {
                          setState(() {
                            _isLoading = true;
                            total = 0;
                            offset = 0;
                            productList.clear();
                          });
                        }
                        getProduct("0");
                        Navigator.pop(context, 'option 3');
                      }),
                  InkWell(
                      child: Container(
                          width: deviceWidth,
                          color: sortBy == 'pv.price' && orderBy == 'DESC'
                              ? colors.primary
                              : Theme.of(context).colorScheme.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Text(
                            getTranslated(context, 'F_HIGH')!,
                            style: Theme.of(context)
                                .textTheme
                                .subtitle1!
                                .copyWith(
                                    color: sortBy == 'pv.price' &&
                                            orderBy == 'DESC'
                                        ? Theme.of(context).colorScheme.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .fontColor),
                          )),
                      onTap: () {
                        sortBy = 'pv.price';
                        orderBy = 'DESC';
                        if (mounted) {
                          setState(() {
                            _isLoading = true;
                            total = 0;
                            offset = 0;
                            productList.clear();
                          });
                        }
                        getProduct("0");
                        Navigator.pop(context, 'option 4');
                      }),
                ]),
          );
        });
      },
    );
  }

  Future<void> addToCart(int index, String qty, int from) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      if (CUR_USERID != null) {
        if (mounted) {
          setState(() {
            _isProgress = true;
          });
        }
        if (int.parse(qty) < productList[index].minOrderQuntity!) {
          qty = productList[index].minOrderQuntity.toString();

          setSnackbar("${getTranslated(context, 'MIN_MSG')}$qty", context);
        }
        var parameter = {
          USER_ID: CUR_USERID,
          PRODUCT_VARIENT_ID:
              productList[index].prVarientList![_oldSelVarient].id,
          QTY: qty
        };
        setState(() {
          productList[index].selVarient = _oldSelVarient;
        });
        apiBaseHelper.postAPICall(manageCartApi, parameter).then((getdata) {
          bool error = getdata["error"];
          String? msg = getdata["message"];
          if (!error) {
            var data = getdata["data"];

            String? qty = data['total_quantity'];
            // CUR_CART_COUNT = data['cart_count'];

            context.read<UserProvider>().setCartCount(data['cart_count']);
            productList[index].prVarientList![_oldSelVarient].cartCount =
                qty.toString();

            var cart = getdata["cart"];
            List<SectionModel> cartList = (cart as List)
                .map((cart) => SectionModel.fromCart(cart))
                .toList();
            context.read<CartProvider>().setCartlist(cartList);
            setSnackBarCustom(
                "${productList[index].name} is added to the cart successfully",
                context);
          } else {
            setSnackbar(msg!, context);
          }
          if (mounted) {
            setState(() {
              _isProgress = false;
            });
          }
        }, onError: (error) {
          setSnackbar(error.toString(), context);
          if (mounted) {
            setState(() {
              _isProgress = false;
            });
          }
        });
      } else {
        setState(() {
          _isProgress = true;
        });

        if (from == 1) {
          int cartCount = await db.getTotalCartCount(context);
          if (int.parse(MAX_ITEMS!) > cartCount) {
            List<Product>? prList = [];
            prList.add(productList[index]);
            context.read<CartProvider>().addCartItem(SectionModel(
                  qty: qty,
                  productList: prList,
                  varientId:
                      productList[index].prVarientList![_oldSelVarient].id!,
                  id: productList[index].id,
                ));
            db.insertCart(
                productList[index].id!,
                productList[index].prVarientList![_oldSelVarient].id!,
                qty,
                context);
          } else {
            setSnackbar(
                "In Cart maximum ${int.parse(MAX_ITEMS!)} product allowed",
                context);
          }
        } else {
          if (int.parse(qty) >
              int.parse(productList[index].itemsCounter!.last)) {
            // qty = productList[index].minOrderQuntity.toString();

            setSnackbar(
                "${getTranslated(context, 'MAXQTY')!} ${productList[index].itemsCounter!.last}",
                context);
          } else {
            context.read<CartProvider>().updateCartItem(
                productList[index].id!,
                qty,
                _oldSelVarient,
                productList[index].prVarientList![_oldSelVarient].id!);
            db.updateCart(productList[index].id!,
                productList[index].prVarientList![_oldSelVarient].id!, qty);
          }
        }
        setState(() {
          _isProgress = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  _showForm() {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.white,
          padding: const EdgeInsets.only(bottom: 15),
          //padding: const EdgeInsets.symmetric(vertical: ),
          child: Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Container(
                    decoration:
                        BoxDecoration(borderRadius: BorderRadius.circular(25)),
                    height: 44,
                    child: TextField(
                      controller: _controller1,
                      autofocus: false,
                      focusNode: searchFocusNode,
                      enabled: true,
                      textAlign: TextAlign.left,
                      decoration: InputDecoration(
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.gray),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(10.0),
                            ),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.transparent),
                            borderRadius: BorderRadius.all(
                              Radius.circular(10.0),
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets.fromLTRB(15.0, 5.0, 0, 5.0),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.transparent),
                            borderRadius: BorderRadius.all(
                              Radius.circular(10.0),
                            ),
                          ),
                          fillColor: Theme.of(context).colorScheme.gray,
                          filled: true,
                          isDense: true,
                          hintText: getTranslated(context, 'searchHint'),
                          hintStyle: Theme.of(context)
                              .textTheme
                              .bodyText2!
                              .copyWith(
                                color: Theme.of(context).colorScheme.fontColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.normal,
                              ),
                          prefixIcon: const Padding(
                              padding: EdgeInsets.all(15.0),
                              child: Icon(Icons.search)),
                          suffixIcon: _controller1.text != ''
                              ? IconButton(
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();

                                    _controller1.text = '';
                                    offset = 0;
                                    getProduct('0');
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: colors.primary,
                                  ),
                                )
                              : InkWell(
                                  child: const Icon(
                                    Icons.mic,
                                    color: colors.primary,
                                  ),
                                  onTap: () {
                                    lastWords = '';
                                    if (!_hasSpeech) {
                                      initSpeechState();
                                    } else {
                                      showSpeechDialog();
                                    }
                                  },
                                )),
                    ),
                  ),
                ),
              ),
              filterOptions(),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? shimmer(context)
              : notificationisnodata
                  ? getNoItem(context)
                  : listType
                      ? ListView.builder(
                          controller: controller,
                          shrinkWrap: true,
                          itemCount: (offset < total)
                              ? productList.length + 1
                              : productList.length,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return (index == productList.length &&
                                    isLoadingmore)
                                ? singleItemSimmer(context)
                                : listItem(index);
                          },
                        )
                      : GridView.count(
                          padding: const EdgeInsetsDirectional.only(top: 5),
                          crossAxisCount: 2,
                          controller: controller,
                          childAspectRatio: 0.6,
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: List.generate(
                            (offset < total)
                                ? productList.length + 1
                                : productList.length,
                            (index) {
                              return (index == productList.length &&
                                      isLoadingmore)
                                  ? simmerSingleProduct(context)
                                  : productItem(
                                      index, index % 2 == 0 ? true : false);
                            },
                          )),
        ),
      ],
    );
  }

  void errorListener(SpeechRecognitionError error) {
    setState(() {
      // lastError = '${error.errorMsg} - ${error.permanent}';
      setSnackbar(error.errorMsg, context);
    });
  }

  void statusListener(String status) {
    setStater(() {
      lastStatus = status;
    });
  }

  void startListening() {
    lastWords = '';
    speech.listen(
        onResult: resultListener,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: _currentLocaleId,
        onSoundLevelChange: soundLevelListener,
        cancelOnError: true,
        listenMode: ListenMode.confirmation);
    setStater(() {});
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);

    setStater(() {
      this.level = level;
    });
  }

  void stopListening() {
    speech.stop();
    setStater(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    speech.cancel();
    setStater(() {
      level = 0.0;
    });
  }

  void resultListener(SpeechRecognitionResult result) {
    setStater(() {
      lastWords = result.recognizedWords;
      query = lastWords.replaceAll(' ', '');
    });

    if (result.finalResult) {
      Future.delayed(const Duration(seconds: 1)).then((_) async {
        clearAll();

        _controller1.text = lastWords;
        _controller1.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller1.text.length));

        setState(() {});
        Navigator.of(context).pop();
      });
    }
  }

  clearAll() {
    setState(() {
      query = _controller1.text;
      offset = 0;
      isLoadingmore = true;
      productList.clear();
    });
  }

  showSpeechDialog() {
    return dialogAnimate(context, StatefulBuilder(
        builder: (BuildContext context, StateSetter setStater1) {
      setStater = setStater1;
      return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.lightWhite,
        title: Text(
          'Search for desired product',
          style: Theme.of(context)
              .textTheme
              .subtitle1!
              .copyWith(color: Theme.of(context).colorScheme.fontColor),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                      blurRadius: .26,
                      spreadRadius: level * 1.5,
                      color:
                          Theme.of(context).colorScheme.black.withOpacity(.05))
                ],
                color: Theme.of(context).colorScheme.white,
                borderRadius: const BorderRadius.all(Radius.circular(50)),
              ),
              child: IconButton(
                  icon: const Icon(
                    Icons.mic,
                    color: colors.primary,
                  ),
                  onPressed: () {
                    if (!_hasSpeech) {
                      initSpeechState();
                    } else {
                      !_hasSpeech || speech.isListening
                          ? null
                          : startListening();
                    }
                  }),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(lastWords),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Theme.of(context).colorScheme.fontColor.withOpacity(0.1),
              child: Center(
                child: speech.isListening
                    ? Text(
                        "I'm listening...",
                        style: Theme.of(context).textTheme.subtitle2!.copyWith(
                            color: Theme.of(context).colorScheme.fontColor,
                            fontWeight: FontWeight.bold),
                      )
                    : Text(
                        'Not listening',
                        style: Theme.of(context).textTheme.subtitle2!.copyWith(
                            color: Theme.of(context).colorScheme.fontColor,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      );
    }));
  }

  Future<void> initSpeechState() async {
    var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: false,
        finalTimeout: const Duration(milliseconds: 0));
    if (hasSpeech) {
      _localeNames = await speech.locales();

      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale?.localeId ?? '';
    }

    if (!mounted) return;

    setState(() {
      _hasSpeech = hasSpeech;
    });
    if (hasSpeech) showSpeechDialog();
  }

  Widget _tags() {
    if (tagList != null && tagList!.isNotEmpty) {
      List<Widget> chips = [];
      for (int i = 0; i < tagList!.length; i++) {
        tagChip = ChoiceChip(
          selected: false,
          label: Text(tagList![i],
              style: TextStyle(color: Theme.of(context).colorScheme.white)),
          backgroundColor: colors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(25))),
          onSelected: (bool selected) {
            if (mounted) {
              Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => ProductList(
                      name: tagList![i],
                      tag: true,
                      fromSeller: false,
                    ),
                  ));
            }
          },
        );

        chips.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: tagChip));
      }

      return Container(
        height: 50,
        padding: const EdgeInsets.only(bottom: 8.0),
        child: ListView(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            children: chips),
      );
    } else {
      return Container();
    }
  }

  filterOptions() {
    return Container(
      height: 45.0,
      width: deviceWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.gray,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
              onPressed: () {
                filterDialog();
              },
              icon: const Icon(
                Icons.filter_list,
                color: colors.primary,
              ),
              label: Text(
                getTranslated(context, 'FILTER')!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.fontColor,
                ),
              )),
          TextButton.icon(
              onPressed: sortDialog,
              icon: const Icon(
                Icons.swap_vert,
                color: colors.primary,
              ),
              label: Text(
                getTranslated(context, 'SORT_BY')!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.fontColor,
                ),
              )),
          // InkWell(
          //   child: Icon(
          //     listType ? Icons.grid_view : Icons.list,
          //     color: colors.primary,
          //   ),
          //   onTap: () {
          //     productList.isNotEmpty
          //         ? setState(() {
          //             _animationController!.reverse();
          //             _animationController1!.reverse();
          //             listType = !listType;
          //           })
          //         : null;
          //   },
          // ),
        ],
      ),
    );
  }

  void filterDialog() {
    showModalBottomSheet(
      context: context,
      enableDrag: false,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      builder: (builder) {
        _currentRangeValues =
            RangeValues(double.parse(minPrice), double.parse(maxPrice));
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
                padding: const EdgeInsetsDirectional.only(top: 30.0),
                child: AppBar(
                  title: Text(
                    getTranslated(context, 'FILTER')!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.fontColor,
                    ),
                  ),
                  centerTitle: true,
                  elevation: 5,
                  backgroundColor: Theme.of(context).colorScheme.white,
                  leading: Builder(builder: (BuildContext context) {
                    return Container(
                      margin: const EdgeInsets.all(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsetsDirectional.only(end: 4.0),
                          child: Icon(Icons.arrow_back_ios_rounded,
                              color: colors.primary),
                        ),
                      ),
                    );
                  }),
                )),
            Expanded(
                child: Container(
              color: Theme.of(context).colorScheme.lightWhite,
              padding: const EdgeInsetsDirectional.only(
                  start: 7.0, end: 7.0, top: 7.0),
              child: filterList != null
                  ? ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      padding: const EdgeInsetsDirectional.only(top: 10.0),
                      itemCount: filterList.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            children: [
                              SizedBox(
                                  width: deviceWidth,
                                  child: Card(
                                      elevation: 0,
                                      child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Price Range',
                                            style: Theme.of(context)
                                                .textTheme
                                                .subtitle1!
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .lightBlack,
                                                    fontWeight:
                                                        FontWeight.normal),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          )))),
                              SliderTheme(
                                data: const SliderThemeData(
                                    valueIndicatorTextStyle:
                                        TextStyle(color: Colors.white)),
                                child: RangeSlider(
                                  values: _currentRangeValues!,
                                  min: double.parse(minPrice),
                                  max: double.parse(maxPrice),
                                  divisions: 10,
                                  labels: RangeLabels(
                                    _currentRangeValues!.start
                                        .round()
                                        .toString(),
                                    _currentRangeValues!.end.round().toString(),
                                  ),
                                  onChanged: (RangeValues values) {
                                    setState(() {
                                      _currentRangeValues = values;
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        } else {
                          index = index - 1;
                          attsubList =
                              filterList[index]['attribute_values'].split(',');

                          attListId = filterList[index]['attribute_values_id']
                              .split(',');

                          List<Widget?> chips = [];
                          List<String> att =
                              filterList[index]['attribute_values']!.split(',');

                          List<String> attSType =
                              filterList[index]['swatche_type'].split(',');

                          List<String> attSValue =
                              filterList[index]['swatche_value'].split(',');

                          for (int i = 0; i < att.length; i++) {
                            Widget itemLabel;
                            if (attSType[i] == "1") {
                              String clr = (attSValue[i].substring(1));

                              String color = "0xff$clr";

                              itemLabel = Container(
                                width: 25,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(int.parse(color))),
                              );
                            } else if (attSType[i] == "2") {
                              itemLabel = ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Image.network(attSValue[i],
                                      width: 80,
                                      height: 80,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              erroWidget(80)));
                            } else {
                              itemLabel = Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(att[i],
                                    style: TextStyle(
                                        color:
                                            selectedId.contains(attListId![i])
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .white
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .fontColor)),
                              );
                            }

                            choiceChip = ChoiceChip(
                              selected: selectedId.contains(attListId![i]),
                              label: itemLabel,
                              labelPadding: const EdgeInsets.all(0),
                              selectedColor: colors.primary,
                              backgroundColor:
                                  Theme.of(context).colorScheme.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    attSType[i] == "1" ? 100 : 10),
                                side: BorderSide(
                                    color: selectedId.contains(attListId![i])
                                        ? colors.primary
                                        : colors.black12,
                                    width: 1.5),
                              ),
                              onSelected: (bool selected) {
                                attListId = filterList[index]
                                        ['attribute_values_id']
                                    .split(',');

                                if (mounted) {
                                  setState(() {
                                    if (selected == true) {
                                      selectedId.add(attListId![i]);
                                    } else {
                                      selectedId.remove(attListId![i]);
                                    }
                                  });
                                }
                              },
                            );

                            chips.add(choiceChip);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: deviceWidth,
                                child: Card(
                                  elevation: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      filterList[index]['name'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .subtitle1!
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .fontColor,
                                              fontWeight: FontWeight.normal),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                              ),
                              chips.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Wrap(
                                        children:
                                            chips.map<Widget>((Widget? chip) {
                                          return Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: chip,
                                          );
                                        }).toList(),
                                      ),
                                    )
                                  : Container()
                            ],
                          );
                        }
                      })
                  : Container(),
            )),
            Container(
              color: Theme.of(context).colorScheme.white,
              child: Row(children: <Widget>[
                Container(
                  margin: const EdgeInsetsDirectional.only(start: 20),
                  width: deviceWidth! * 0.4,
                  child: OutlinedButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          selectedId.clear();
                        });
                      }
                    },
                    child: Text(getTranslated(context, 'DISCARD')!),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 20),
                  child: SimBtn(
                      width: 0.4,
                      height: 35,
                      title: getTranslated(context, 'APPLY'),
                      onBtnSelected: () {
                        selId = selectedId.join(',');

                        if (mounted) {
                          setState(() {
                            _isLoading = true;
                            total = 0;
                            offset = 0;
                            productList.clear();
                          });
                        }
                        getProduct("0");
                        Navigator.pop(context, 'Product Filter');
                      }),
                ),
              ]),
            )
          ]);
        });
      },
    );
  }
}
