import 'package:eshop/Model/Section_Model.dart';
import 'package:flutter/cupertino.dart';

class ProductProvider extends ChangeNotifier {

  List<Product> _productList = [];
  int _selectedVariant = 0;
  int get selectedVariant => _selectedVariant;


  get productList => _productList;





  removeCompareList() {

    _productList.clear();

    notifyListeners();
  }



  setProductList(List<Product>? productList) {
    _productList = productList!;
    notifyListeners();
  }

  setSelected(int id, index) {
    _productList[index].selVarient = id;
    _selectedVariant = id;
    notifyListeners();
  }
}