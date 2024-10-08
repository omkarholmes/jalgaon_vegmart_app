import 'package:eshop/Provider/SettingProvider.dart';
import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String userName = '',
      cartCount = '',
      curBal = '',
      mobile = '',
      profilePicture = '',
      emailAdd = '';
  String?  userId = '';

  String? _curPincode = '';

  late SettingProvider settingsProvider;

  String get curUserName => userName;

  String get curPincode => _curPincode ?? '';

  String get curCartCount => cartCount;

  String get curBalance => curBal;

  String get mob => mobile;

  String get profilePic => profilePicture;

  String? get usId => userId;

  String get email => emailAdd;

  void setPincode(String pin) {
    _curPincode = pin;
    notifyListeners();
  }

  void setCartCount(String count) {
    cartCount = count;
    notifyListeners();
  }

  void setBalance(String bal) {
    curBal = bal;
    notifyListeners();
  }

  void setName(String count) {
    //settingsProvider.userName=count;
    userName = count;
    notifyListeners();
  }

  void setMobile(String count) {
    mobile = count;
    notifyListeners();
  }

  void setProfilePic(String count) {
    profilePicture = count;
    notifyListeners();
  }

  void setEmail(String email) {
    emailAdd = email;
    notifyListeners();
  }

  void setUserId(String? count) {
    userId = count;
  }
}
