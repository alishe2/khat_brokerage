import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class S {
  // 'om' = Afaan Oromoo, 'en' = English
  static final ValueNotifier<String> currentLocale = ValueNotifier<String>('om');

  static bool get isOromo => currentLocale.value == 'om';

  static const String _prefKey = 'app_language';

  /// Call this once in main() before runApp() to load the saved language
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString(_prefKey) ?? 'om';
    currentLocale.value = savedLang;
  }

  /// Toggle or set the language ('om' or 'en')
  static Future<void> setLanguage(String langCode) async {
    if (langCode != 'om' && langCode != 'en') return;
    currentLocale.value = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, langCode);
  }

  // ------------------------------------------------------------
  // APPLICATION & BRANDING
  // ------------------------------------------------------------
  static String get appTitle => isOromo ? "Dallaala Jimaa" : "Khat Brokerage";
  static String get appSubtitle =>
      isOromo ? "Sirna Bulchiinsa Daldala Jimaa" : "Business Management System";

  // ------------------------------------------------------------
  // COMMON & ACTIONS
  // ------------------------------------------------------------
  static String get language => isOromo ? "Afaan" : "Language";
  static String get afaanOromoo => "Afaan Oromoo";
  static String get english => "English";
  static String get login => isOromo ? "Seensaa" : "Login";
  static String get signOut => isOromo ? "Bahi" : "Sign Out";
  static String get save => isOromo ? "Olkaayi" : "Save";
  static String get cancel => isOromo ? "Dhiisi" : "Cancel";
  static String get delete => isOromo ? "Haqi" : "Delete";
  static String get edit => isOromo ? "Gulaali" : "Edit";
  static String get done => isOromo ? "Xumuri" : "Done";
  static String get close => isOromo ? "Cufi" : "Close";
  static String get search => isOromo ? "Barbaadi..." : "Search...";
  static String get birr => isOromo ? "Qarshii" : "Birr";
  static String get kilo => isOromo ? "Kiiloo" : "Kilo";
  static String get date => isOromo ? "Guyyaa" : "Date";
  static String get reason => isOromo ? "Sababa" : "Reason";
  static String get phone => isOromo ? "Lakkoofsa Bilbilaa" : "Phone number";
  static String get fullName => isOromo ? "Maqaa Guutuu" : "Full name";
  static String get total => isOromo ? "Idaa'ama" : "Total";
  static String get amount => isOromo ? "Hamma Maallaqaa" : "Amount";
  static String get all => isOromo ? "Hunda" : "All";
  static String get today => isOromo ? "Har'a" : "Today";
  static String get yesterday => isOromo ? "Kaleessa" : "Yesterday";
  static String get thisWeek => isOromo ? "Torban Kana" : "This Week";
  static String get thisMonth => isOromo ? "Ji'a kana" : "This Month";
  static String get allTime => isOromo ? "Waliigala" : "All Time";
  static String get customRange => isOromo ? "Guyyoota Filataman" : "Custom Range";
  static String get notRecorded => isOromo ? "Hin Galmoofne" : "Not recorded";
  static String get pendingStatus => isOromo ? "Eeggachaa Jira" : "Pending";

  // ------------------------------------------------------------
  // ROLES & AUTH (iccitii)
  // ------------------------------------------------------------
  static String get admin => isOromo ? "Abbaa Qabeenyaa" : "Administrator";
  static String get accountant => isOromo ? "Barreesaa" : "Accountant";
  static String get password => isOromo ? "Jecha Iccitii" : "Password";
  static String get newPassword => isOromo ? "Jecha Iccitii Haaraa" : "New password";
  static String get confirmPassword => isOromo ? "Jecha Iccitii Mirkaneessi" : "Confirm password";
  static String get changePassword => isOromo ? "Jecha Iccitii Jijjiiri" : "Change Password";

  // ------------------------------------------------------------
  // CORE ENTITIES (Qotee Bulaa, Bitaa, Gurguraa)
  // ------------------------------------------------------------
  static String get farmers => isOromo ? "Qotee Bulaa" : "Farmers";
  static String get farmer => isOromo ? "Qotee Bulaa" : "Farmer";
  static String get addFarmer => isOromo ? "Qotee Bulaa Galmeessi" : "Add Farmer";
  static String get farmerCode => isOromo ? "Koodii Qotee Bulaa" : "Farmer ID";

  static String get buyers => isOromo ? "Bitaa" : "Buyers";
  static String get buyer => isOromo ? "Bitaa" : "Buyer";
  static String get addBuyer => isOromo ? "Bitaa Galmeessi" : "Add Buyer";
  static String get buyerCode => isOromo ? "Koodii Bitaa" : "Buyer ID";
  static String get groupName => isOromo ? "Maqaa Garee" : "Group name";

  static String get sellers => isOromo ? "Gurguraa" : "Sellers";
  static String get seller => isOromo ? "Gurguraa" : "Seller";
  static String get addSeller => isOromo ? "Gurguraa Galmeessi" : "Add Seller";
  static String get sellerCode => isOromo ? "Koodii Gurguraa" : "Seller Code";

  // ------------------------------------------------------------
  // SALES & COMMISSIONS
  // ------------------------------------------------------------
  static String get recordSale => isOromo ? "Gurgurtaa Galmeessi" : "Record Sale";
  static String get sale => isOromo ? "Gurgurtaa" : "Sale";
  static String get sales => isOromo ? "Gurgurtaawwan" : "Sales";
  static String get totalKilo => isOromo ? "Idaa'ama Kiiloo" : "Total Kilo";
  static String get kiloSold => isOromo ? "Kiiloo Gurgurame" : "Kilo Sold";
  static String get pricePerKilo => isOromo ? "Gatii Kiiloo Tokkoo" : "Price / Kilo";
  static String get addPriceLine => isOromo ? "Gatii Dabalataa Galchi" : "Add Price Line";
  static String get commission => isOromo ? "Koomishinii" : "Commission";
  static String get advanceLoan => isOromo ? "Liqii duursee fudhate" : "Advance Loan";
  static String get totalSales => isOromo ? "Waliigala Gurgurtaa" : "Total Sales";
  static String get farmerAmount => isOromo ? "Maallaqa Qotee Bulaa" : "Farmer Amount";
  static String get transactionCode => isOromo ? "koodii Tiraanzaakshiini" : "Transaction Code";

  // ------------------------------------------------------------
  // PAYMENTS & DEBT
  // ------------------------------------------------------------
  static String get paidAmount => isOromo ? "Hanga kaffalame" : "Paid Amount";
  static String get unpaidAmount => isOromo ? "Kan Hin Kaffalamne" : "Unpaid";
  static String get buyerPaid => isOromo ? "Bitaan Kan Kaffale" : "Buyer Paid";
  static String get buyerUnpaid => isOromo ? "Bitaan Kan Hin Kaffalin" : "Buyer Unpaid";
  static String get currentDebt => isOromo ? "Liqii Ammaa" : "Current Debt";
  static String get buyerDebt => isOromo ? "Liqii Bitaa" : "Buyer Debt";
  static String get payDebt => isOromo ? "Liqii Kaffali" : "Pay Debt";
  static String get adjustDebt => isOromo ? "Liqii Sirreessi" : "Adjust Debt";
  static String get paidFromOldDebt => isOromo ? "Liqii Duraanii Kan Kaffalame" : "Paid From Old Debt";
  static String get totalPaid => isOromo ? "kaffaltii waliigalaa" : "Total Paid";

  // ------------------------------------------------------------
  // WITHDRAWALS & BALANCES
  // ------------------------------------------------------------
  static String get currentBalance => isOromo ? "Haftee Maallaqaa" : "Current Balance";
  static String get farmerMoney => isOromo ? "Maallaqa Qotee Bulaa" : "Farmer Money";
  static String get withdraw => isOromo ? "Maallaqa Baasi" : "Withdraw";
  static String get withdrawal => isOromo ? "Baasii" : "Withdrawal";
  static String get withdrawals => isOromo ? "Baasiiwwan" : "Withdrawals";
  static String get farmerWithdrawal => isOromo ? "Maallaqa Qotee Bulaan Baase" : "Farmer Withdrawal";
  static String get adjustBalance => isOromo ? "Haftee Sirreessi" : "Adjust Balance";
  static String get remainingBalance => isOromo ? "Haftee Herreegaa" : "Remaining Balance";

  // ------------------------------------------------------------
  // EXPENSES & PROFIT
  // ------------------------------------------------------------
  static String get expenses => isOromo ? "Baasiiwwan" : "Expenses";
  static String get workerFees => isOromo ? "Mindaa Hojjattootaa" : "Worker Fees";
  static String get otherExpenses => isOromo ? "Baasiiwwan Biroo" : "Other Expenses";
  static String get adminProfit => isOromo ? "Bu'aa Qulqulluu" : "Admin Profit";

  // ------------------------------------------------------------
  // DASHBOARD & REPORTS
  // ------------------------------------------------------------
  static String get dashboard => isOromo ? "Daashboordii" : "Dashboard";
  static String get adminDashboard => isOromo ? "Daashboordii Abbaa Qabeenyaa" : "Admin Dashboard";
  static String get accountantDashboard => isOromo ? "Daashboordii Barreesaa" : "Accountant Dashboard";
  static String get transactions => isOromo ? "Tiraanzaakshiinawwan" : "Transactions";
  static String get transactionHistory => isOromo ? "Seenaa Tiraanzaakshiinii" : "Transaction History";
  static String get reports => isOromo ? "Gabaasa" : "Reports";
  static String get quickActions => isOromo ? "Tajaajiloota Ariifachiisoo" : "Quick Actions";
  static String get overallBusiness => isOromo ? "Waliigala Haala Hojii" : "Overall Business";
  static String get todaysOverview => isOromo ? "Ibsa Hojii Har'aa" : "Today's business overview";

  // ------------------------------------------------------------
  // SETTLEMENT STATUS (CHECKABLE SALE)
  // ------------------------------------------------------------
  static String get settled => isOromo ? "Qulqullaa'eera" : "Settled";
  static String get unsettled => isOromo ? "Hin Qulqulloofne" : "Unsettled";
  static String get pending => isOromo ? "Eeggachaa Jira" : "Pending";
  static String get markAsSettled => isOromo ? "Akka Qulqullaa'etti Galmeessi" : "Mark as Settled / Paid Out";
  static String get markAsPending => isOromo ? "Akka Eeggachuutti Deebisi" : "Mark as Pending (Unsettled)";

  // ============================================================
  // ERROR & VALIDATION MESSAGES
  // ============================================================
  static String get errInvalidPhoneOrPassword =>
      isOromo ? "Lakkoofsi bilbilaa yookiin jechi iccitii sirrii miti." : "Invalid phone number or password.";
  static String get errEnterPhone =>
      isOromo ? "Mee lakkoofsa bilbilaa keessan galchaa." : "Enter your phone number.";
  static String get errEnterPassword =>
      isOromo ? "Mee jecha iccitii keessan galchaa." : "Enter your password.";
  static String get errPasswordTooShort =>
      isOromo ? "Jechi iccitii qubee 6 gadi ta'uu hin danda'u." : "Password must be at least 6 characters.";
  static String get errPasswordMismatch =>
      isOromo ? "Jechi iccitii fi kan mirkaneessaa walsimuu hin dandeenye." : "Passwords do not match.";
  static String get errNotLoggedIn =>
      isOromo ? "Isin sirna keessa hin jirtan (Log-in hin goone)." : "You are not logged in.";
  static String get errUserRoleNotFound =>
      isOromo ? "Gaheen hojii keessan hin argamne." : "User role was not found.";

  static String get errSelectFarmer =>
      isOromo ? "Mee qotee bulaa filadhaa." : "Select a farmer.";
  static String get errSelectSeller =>
      isOromo ? "Mee gurguraa filadhaa." : "Select a seller.";
  static String get errEnterValidKilo =>
      isOromo ? "Mee kiiloo sirrii ta'e galchaa." : "Enter a valid total Kilo.";
  static String get errAddAtLeastOneBuyer =>
      isOromo ? "Yoo xiqqaate bitaa tokko galchuu qabdu." : "Add at least one buyer.";
  static String get errAddPriceLineForBuyer =>
      isOromo ? "Mee gatii fi hamma kiiloo bitaa kanaaf galchaa." : "Add at least one price line for this buyer.";
  static String errKiloMismatch(int entered, int calculated) =>
      isOromo
          ? "Garaagarummaa Kiiloo: Kan galchame $entered, garuu kan bittaa keessa jiru $calculated."
          : "Kilo mismatch: entered $entered, but buyer lines contain $calculated.";
  static String get errTotalSalesZero =>
      isOromo ? "Waliigalli gurgurtaa zeeroo (0) caaluu qaba." : "Total sales must be greater than zero.";
  static String get errAdvanceNegative =>
      isOromo ? "Liqii duursee fudhate maallaqa hir'uu (negative) ta'uu hin danda'u." : "Advance loan cannot be negative.";
  static String get errAdvanceExceedsFarmerAmount =>
      isOromo ? "Liqii duursee fudhate maallaqa qotee bulaa caaluu hin danda'u." : "Advance loan cannot exceed farmer amount.";
  static String get errPaidNegative =>
      isOromo ? "Maallaqni kaffalame hir'uu ta'uu hin danda'u." : "Paid amount cannot be negative.";
  static String get errPaidExceedsTotal =>
      isOromo ? "Maallaqni kaffalame liqiii waliigalaa caaluu hin danda'u." : "Paid amount cannot exceed buyer total.";

  static String get errEnterWithdrawalAmount =>
      isOromo ? "Mee hamma maallaqa baasuu barbaaddanii galchaa." : "Enter a valid withdrawal amount.";
  static String errWithdrawalExceedsBalance(String balance) =>
      isOromo
          ? "Haftee qabdan ($balance) caalaa baasuu hin dandeessan."
          : "Withdrawal cannot exceed available balance ($balance).";

  static String get errEnterPaymentAmount =>
      isOromo ? "Mee hamma kaffaltii sirrii ta'e galchaa." : "Enter a valid payment amount.";
  static String get errNoDebtToPay =>
      isOromo ? "Bitaan kun liqii irra jiru hin qabu." : "This buyer has no outstanding debt.";
  static String errPaymentExceedsDebt(String debt) =>
      isOromo
          ? "Kaffaltiin liqii jiru ($debt) caaluu hin danda'u."
          : "Payment cannot exceed current debt ($debt).";

  static String get errEnterValidAdjustmentAmount =>
      isOromo ? "Mee hamma maallaqa sirreessaa sirrii ta'e galchaa." : "Enter a valid adjustment amount.";
  static String get errEnterReason =>
      isOromo ? "Mee sababa sirreeffama kanaa barreessaa." : "Enter a reason for the adjustment.";

  static String errLoadingData(String err) =>
      isOromo ? "Oodeeffannoo fiduun hin danda'amne: $err" : "Could not load data: $err";
  static String errSavingData(String err) =>
      isOromo ? "Galmeessuun hin danda'amne: $err" : "Could not save: $err";
  static String get msgSavedSuccessfully =>
      isOromo ? "Milkaa'inaan galmaa'eera." : "Saved successfully.";
  static String get msgDeletedSuccessfully =>
      isOromo ? "Milkaa'inaan haqameera." : "Deleted successfully.";
  static String get msgConfirmDelete =>
      isOromo ? "Mirkaneeffadhaa: Haquu akka barbaaddan beektuu?" : "Are you sure you want to delete this?";
}