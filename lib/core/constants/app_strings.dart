/// Centralized user-facing strings. The app is Bangla-first, so all
/// visible copy is keyed here. Backend-driven content (e.g. crop names
/// from a library) lives in its own service.
class AppStrings {
  AppStrings._();

  // Brand
  static const String appName = 'Krishi AI';
  static const String appTagline =
      'AI-powered smart farming assistance for Bangladesh';
  static const String tagline = 'AI-চালিত স্মার্ট কৃষি সহায়তা';

  // Common
  static const String retry = 'আবার চেষ্টা করুন';
  static const String seeAll = 'সব দেখুন';
  static const String save = 'সংরক্ষণ করুন';
  static const String cancel = 'বাতিল';
  static const String delete = 'মুছুন';
  static const String edit = 'সম্পাদনা';
  static const String add = 'যোগ করুন';
  static const String done = 'সম্পন্ন';
  static const String next = 'পরবর্তী';
  static const String back = 'পূর্বে';
  static const String getStarted = 'শুরু করুন';
  static const String skip = 'এড়িয়ে যান';
  static const String skipForNow = 'এখন এড়িয়ে যান';
  static const String continue_ = 'চালিয়ে যান';
  static const String required = 'আবশ্যক';

  // Onboarding
  static const String onboardTitle = 'আপনার ফসলের AI সহচর';
  static const String onboardSubtitle =
      'রোগ শনাক্তকরণ, বাজারদর, আবহাওয়া ও লাভের হিসাব — সব এক অ্যাপে।';
  static const String onboardTitle1 = 'AI দিয়ে ফসলের রোগ শনাক্ত করুন';
  static const String onboardSubtitle1 =
      'ছবি তুলুন, AI বলে দেবে রোগের নাম, কারণ ও প্রতিকার।';
  static const String onboardTitle2 = 'স্মার্ট আবহাওয়া ও পরামর্শ';
  static const String onboardSubtitle2 =
      'আপনার এলাকার আবহাওয়া ও ৭ দিনের পূর্বাভাস দেখুন, সেচ ও সারের সিদ্ধান্ত নিন।';
  static const String onboardTitle3 = 'সঠিক বাজারদর এক নজরে';
  static const String onboardSubtitle3 =
      'নিত্যদিনের হালনাগাদ বাজারদর দেখুন, প্রিয় ফসল ফলো করুন।';
  static const String onboardTitle4 = 'লাভ-ক্ষতির হিসাব পকেটে';
  static const String onboardSubtitle4 =
      'খরচ যোগ করুন, লাভের পূর্বাভাস পান, চাষ আরও লাভজনক করুন।';
  static const String onboardingTitle1 = 'Krishi AI তে স্বাগতম';
  static const String onboardingDesc1 =
      'বাংলাদেশের কৃষকদের জন্য AI-চালিত স্মার্ট কৃষি সহায়তা।';
  static const String onboardingTitle2 = 'আপনার ফসল, আমাদের যত্ন';
  static const String onboardingDesc2 =
      'ফসলের রোগ শনাক্তকরণ, স্মার্ট কৃষি পরামর্শ, আবহাওয়া বিশ্লেষণ ও খামার ব্যবস্থাপনা — সব এক জায়গায়।';

  // Onboarding pages (indexed removed — duplicates unified above)
  // Permissions
  static const String permissionsTitle = 'প্রয়োজনীয় অনুমতিসমূহ';
  static const String permissionsDesc =
      'ভালো অভিজ্ঞতার জন্য নিচের অনুমতিগুলো দিন। আপনি চাইলে পরেও দিতে পারবেন।';
  static const String permissionsIntro =
      'ক্যামেরা ও মাইক্রোফোন অনুমতি দিলে আপনি ফসল স্ক্যান ও ভয়েস প্রশ্ন করতে পারবেন।';
  static const String cameraTitle = 'ক্যামেরা';
  static const String cameraDesc = 'ফসলের ছবি তুলে রোগ শনাক্ত করতে';
  static const String cameraAccess = 'ক্যামেরা অ্যাক্সেস';
  static const String cameraAccessDesc =
      'ফসলের ছবি তুলে AI দিয়ে রোগ শনাক্ত করতে';
  static const String locationTitle = 'অবস্থান';
  static const String locationDesc = 'স্থানীয় আবহাওয়া ও পরামর্শ পেতে';
  static const String microphoneTitle = 'মাইক্রোফোন';
  static const String microphoneDesc = 'বাংলায় ভয়েস প্রশ্ন করতে';
  static const String microphoneAccess = 'মাইক্রোফোন অ্যাক্সেস';
  static const String microphoneAccessDesc =
      'AI সহকারীকে বাংলায় ভয়েস প্রশ্ন করতে';
  static const String notificationsTitle = 'নোটিফিকেশন';
  static const String notificationsDesc =
      'গুরুত্বপূর্ণ সতর্কতা ও রিমাইন্ডার পেতে';
  static const String storageAccess = 'স্টোরেজ অ্যাক্সেস';
  static const String storageAccessDesc = 'ছবি ও ডায়াগনসিস সংরক্ষণ করতে';
  static const String grant = 'অনুমতি দিন';
  static const String granted = 'অনুমতি দেওয়া হয়েছে';

  // Profile setup
  static const String profileSetup = 'প্রোফাইল সেটআপ';
  static const String profileSetupHint =
      'ব্যক্তিগতকৃত পরামর্শ দিতে নিচের তথ্যগুলো পূরণ করুন।';
  static const String profileSetupTitle = 'আপনার সম্পর্কে জানি';
  static const String profileSetupDesc =
      'ব্যক্তিগতকৃত পরামর্শ দিতে কিছু তথ্য প্রয়োজন।';
  static const String fullName = 'পুরো নাম';
  static const String district = 'জেলা';
  static const String upazila = 'উপজেলা';
  static const String farmingExperience = 'কৃষি অভিজ্ঞতা (বছর)';
  static const String experienceYears = 'অভিজ্ঞতা (বছর)';
  static const String farmSize = 'খামারের আকার (একর)';
  static const String farmSizeAcres = 'খামারের আকার (একর)';
  // Onboarding pages (indexed removed — duplicates unified above)
  static const String mainCrop = 'প্রধান ফসল';
  static const String preferredLanguage = 'পছন্দের ভাষা';
  static const String languageLabel = 'ভাষা';
  static const String bangla = 'বাংলা';
  static const String english = 'English';

  // Tabs
  static const String tabHome = 'হোম';
  static const String tabFarm = 'আমার খামার';
  static const String tabAI = 'AI';
  static const String tabAi = 'AI';
  static const String tabMarket = 'বাজার';
  static const String tabProfile = 'প্রোফাইল';

  // Home
  static const String today = 'আজ';
  static const String greetingMorning = 'সুপ্রভাত';
  static const String greetingNoon = 'শুভ দুপুর';
  static const String greetingEvening = 'শুভ সন্ধ্যা';
  static const String scanCrop = 'গাছের ছবি তুলুন';
  static const String askAI = 'AI কে জিজ্ঞেস করুন';
  static const String addCrop = 'নতুন ফসল যোগ করুন';
  static const String addExpense = 'খরচ যোগ করুন';
  // Farm / crop forms
  static const String selectFarm = 'খামার নির্বাচন করুন';
  static const String cropName = 'ফসলের নাম';
  static const String cropNameHint = 'যেমন: ধান';
  static const String variety = 'জাত';
  static const String landSize = 'জমির আকার (একর)';
  static const String growDays = 'বৃদ্ধির দিন';
  static const String plantingDate = 'রোপণের তারিখ';
  static const String expectedHarvest = 'প্রত্যাশিত ফসল কাটা';
  static const String currentStage = 'বর্তমান পর্যায়';
  static const String notesOptional = 'নোট (ঐচ্ছিক)';
  static const String needFarmFirst = 'প্রথমে একটি খামার যোগ করুন';
  static const String change = 'পরিবর্তন';
  static const String saving = 'সংরক্ষণ হচ্ছে...';
  static const String checkWeather = 'আবহাওয়া দেখুন';
  static const String farmHealth = 'খামারের স্বাস্থ্য';
  static const String todaysAdvice = 'আজকের কৃষি পরামর্শ';
  static const String myCrop = 'আমার ফসল';
  static const String cropDoctor = 'AI ফসল ডাক্তার';
  // Farm / crop forms extra
  static const String addFarm = 'নতুন খামার যোগ করুন';
  static const String farmName = 'খামারের নাম';
  static const String farmNameHint = 'যেমন: পশ্চিম পাড়ার জমি';
  static const String farmLocation = 'অবস্থান';
  static const String farmLocationHint = 'যেমন: খুলনা সদর';
  static const String soilType = 'মাটির ধরন';
  static const String farmNotes = 'নোট (ঐচ্ছিক)';
  // Farm profile (v2 — personal farmer)
  static const String farmOwnerName = 'মালিকের নাম';
  static const String farmOwnerNameHint = 'যেমন: রহিম মিয়া';
  static const String farmLandOwnership = 'জমির মালিকানা';
  static const String farmWaterSource = 'পানির উৎস';
  static const String farmLastSoilTest = 'শেষ মাটি পরীক্ষা';
  static const String farmNextSoilTest = 'পরবর্তী মাটি পরীক্ষা';
  static const String farmSoilTestOverdue = 'মাটি পরীক্ষার সময় পেরিয়েছে';
  static const String farmSoilTestDue = 'মাটি পরীক্ষা আসন্ন';
  static const String farmSoilTestNone = 'এখনও কোনো মাটি পরীক্ষা হয়নি';
  static const String pickDate = 'তারিখ বাছাই করুন';
  static const String notSet = 'সেট করা হয়নি';
  static const String farmProfile = 'খামারের প্রোফাইল';
  static const String farmCropsHere = 'এই খামারের ফসল';
  static const String farmNoCropsHere = 'এই খামারে এখনও কোনো ফসল নেই';
  static const String addCropToFarm = 'এই খামারে ফসল যোগ করুন';
  static const String editFarm = 'খামার সম্পাদনা';
  static const String crop = 'ফসল';
  static const String cropNotFound = 'ফসল পাওয়া যায়নি';
  static const String unknownFarm = 'অজানা খামার';
  static const String deleteCrop = 'ফসল মুছে ফেলুন';
  static const String deleteCropConfirm = 'এই ফসলটি মুছে ফেলতে চান?';
  static const String planted = 'রোপিত';
  static const String area = 'আয়তন';
  static const String acres = 'একর';
  static const String irrigation = 'সেচ';
  static const String soil = 'মাটি';
  static const String stage = 'পর্যায়';
  static const String timeline = 'সময়রেখা';
  static const String expenses = 'খরচ';
  static const String noExpenses = 'এই ফসলে এখনও কোনো খরচ নেই';
  static const String addExpenseHint = 'নিচে খরচ যোগ করুন';
  static const String notes = 'নোট';
  static const String addCropHere = 'নতুন ফসল যোগ করুন';
  // Farm / crop list
  static const String myFarms = 'আমার খামার';
  static const String farms = 'খামার';
  static const String crops = 'ফসল';
  static const String myCrops = 'আমার ফসল';
  static const String noFarmsYet = 'এখনও কোনো খামার যোগ করা হয়নি';
  static const String addFirstFarm = 'প্রথম খামার যোগ করুন';
  static const String noCropsYet = 'এখনও কোনো ফসল যোগ করা হয়নি';
  static const String addFirstCrop = 'প্রথম ফসল যোগ করুন';
  static const String allCrops = 'সব ফসল';
  static const String noCropsOnFarm = 'এই খামারে কোনো ফসল নেই';
  static const String addFirstCropToFarm = 'এই খামারে প্রথম ফসল যোগ করুন';
  static const String fieldRequired = 'এই তথ্য দিন';
  // My Farm screen
  static const String farmLoadingHeader = 'আপনার খামার লোড হচ্ছে...';
  static const String farmQuickActionsHeader = 'দ্রুত অ্যাকশন';
  static const String farmQuickActionsSubtitle = 'এক ট্যাপে সবকিছু';
  static const String farmQuickAddCrop = 'নতুন ফসল';
  static const String farmQuickAddCropHint = 'খামারে ফসল যোগ করুন';
  static const String farmQuickCropDoctor = 'AI ডাক্তার';
  static const String farmQuickCropDoctorHint = 'রোগ স্ক্যান ও শনাক্ত';
  static const String farmQuickExpense = 'খরচ যোগ';
  static const String farmQuickExpenseHint = 'আজকের খরচ লিখুন';
  static const String farmQuickWeather = 'আবহাওয়া';
  static const String farmQuickWeatherHint = 'পরবর্তী ৭ দিনের পূর্বাভাস';
  static const String farmHealthHeader = 'খামারের স্বাস্থ্য';
  static const String farmHealthEmpty = 'এখনো কোনো ফসল নেই';
  static const String farmHealthEmptyHint =
      'প্রথম ফসল যোগ করলে স্বাস্থ্য সারসংক্ষেপ দেখতে পাবেন।';
  static const String farmHealthGood = 'সব ভালো';
  static const String farmHealthWatch = 'নজর রাখুন';
  static const String farmHealthAction = 'পদক্ষেপ নিন';
  static const String farmStagePlanted = 'রোপণ';
  static const String farmStageGrowing = 'বর্ধনশীল';
  static const String farmStageHarvest = 'ফসলের জন্য প্রস্তুত';
  static const String farmCardCrops = 'ফসল';
  static const String farmCardAcres = 'একর';
  static const String farmCardEdit = 'সম্পাদনা';
  static const String farmCardDelete = 'মুছুন';
  static const String farmFilterAll = 'সব';
  static const String farmFilterWithCrops = 'ফসলসহ';
  static const String farmFilterEmpty = 'খালি';
  static const String farmSwipeHint = 'বামে সোয়াইপ করে মুছুন';
  static const String farmLastUpdated = 'সর্বশেষ হালনাগাদ';

  // AI crop doctor
  static const String analyzing = 'আপনার ফসল বিশ্লেষণ হচ্ছে...';
  static const String diagnosisSaved = 'রোগ নির্ণয় সংরক্ষিত হয়েছে';
  static const String severity = 'তীব্রতা';
  static const String confidence = 'নির্ভরযোগ্যতা';
  static const String symptoms = 'লক্ষণসমূহ';
  static const String possibleCauses = 'সম্ভাব্য কারণ';
  static const String management = 'সাধারণ ব্যবস্থাপনা';
  static const String prevention = 'প্রতিরোধ';
  static const String seekExpert = 'বিশেষজ্ঞের পরামর্শ নিন';
  static const String saveDiagnosis = 'সংরক্ষণ করুন';
  static const String share = 'শেয়ার';
  static const String scanAnother = 'আরেকটি ফসল স্ক্যান করুন';
  static const String scanHistory = "স্ক্যান ইতিহাস";
  static const String scanHistoryNew = "নতুন স্ক্যান";
  static const String scanHistoryEmpty = "কোনো স্ক্যান ইতিহাস নেই";
  static const String scanHistoryHint =
      "কোনো ফসল স্ক্যান করলে ফলাফল এখানে সংরক্ষিত থাকবে।";
  static const String scanHistoryLoading = "স্ক্যান ইতিহাস লোড হচ্ছে...";

  // Market
  static const String marketTitle = 'বাজারদর';
  static const String marketSearchHint = 'ফসল বা পণ্য খুঁজুন';
  static const String marketAll = 'সব';
  static const String marketFavorites = 'প্রিয়';
  static const String marketFavoritesEmpty = 'এখনও কোনো প্রিয় পণ্য নেই';
  static const String marketNoResults = 'এই নামে কোনো পণ্য পাওয়া যায়নি';
  static const String marketCategoryAll = 'সব ক্যাটাগরি';
  static const String marketUpdated = 'হালনাগাদ';
  static const String marketPerUnit = 'প্রতি';
  static const String marketPriceLabel = 'বর্তমান দর';
  static const String marketPreviousLabel = 'গতকালের দর';
  static const String marketMinMax = 'সর্বনিম্ন - সর্বোচ্চ';
  static const String marketTrendUp = 'বাড়তি';
  static const String marketTrendDown = 'কমতি';
  static const String marketTrendStable = 'স্থিতিশীল';
  static const String marketChart14Day = 'গত ১৪ দিনের দর';
  static const String marketRelated = 'এই ক্যাটাগরির আরও';
  static const String marketSource = 'উৎস';
  static const String marketSourceDam = 'DAM সরকারি ডেটা';
  static const String marketSourceBundled = 'অনুমানিত তথ্য';
  static const String marketRefresh = 'রিফ্রেশ';
  static const String marketDetails = 'বিস্তারিত';
  static const String marketPriceHint = '৳/ইউনিট';
  static const String marketFavoritesCount = 'প্রিয় পণ্য';
  static const String marketTotalCount = 'মোট পণ্য';
  static const String marketInMarkets = 'বাজারে আছে';
  static const String marketFavoritesEmptyHint =
      'প্রিয় পণ্যে স্টার আইকনে চাপ দিয়ে যোগ করুন।';
  static const String marketSearchEmptyHint =
      'অন্য ক্যাটাগরি বা ফসলের নাম চেষ্টা করুন।';

  // Disclaimers
  static const String aiDisclaimer =
      'এই পরামর্শ সাধারণ তথ্যমূলক নির্দেশনা। গুরুতর সমস্যায় স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন।';
  static const String weatherDisclaimer =
      'আবহাওয়ার তথ্য সাধারণ নির্দেশনা। প্রকৃত সিদ্ধান্তের আগে স্থানীয় পূর্বাভাস যাচাই করুন।';
  static const String marketDisclaimer =
      'বাজারদর নির্দেশনামূলক। সরকারি/বাজার সূত্র থেকে আসল দর যাচাই করুন।';
  static const String profitDisclaimer =
      'আনুমানিক হিসাব আপনার দেওয়া তথ্যের উপর ভিত্তি করে। প্রকৃত ফলাফল ভিন্ন হতে পারে।';


  // ML-powered crop doctor (rice disease classifier).
  static const String aiModelDisclaimer =
      'এটি একটি সম্ভাব্য রোগ নির্ণয় (AI প্রাথমিক পরামর্শ), চূড়ান্ত নিশ্চিত নয়। সঠিক নির্ণয় ও ব্যবস্থাপনার জন্য স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন।';
  static const String aiModelLowConfidence =
      'AI মডেল য�েষ্ট নিশ্চিত নয়। পরিষ্কার ছবি তুলে আবার চেষ্টা করুন অথবা বিশেষজ্ঞের পরামর্� নিন।';
  static const String aiModelBackendOffline =
      'AI মডেল সার্ভার এখন অনলাইনে নেই — লাইব্রেরি-ভিত্তিক পরামর্শ দেখানো হচ্ছে।';
  static const String aiModelTopPredictions = 'সম্�াব্য রোগের তালিকা';
  static const String aiModelConfidenceLabel = 'নিশ্চিতার মাত্রা';
  static const String aiModelAddPhotoHint =
      'সঠিক নির্ণয়ের জন্য আক্রান্ত পাতার কাছ থেকে একটি ছবি যোগ করুন।';
  static const String aiModelRunningOnServer = 'AI মডেল সার্ভারে চলছে';
  static const String aiModelInferenceTime = 'বিশ্লেষণ সময়';

  // Subscription
  static const String free = 'ফ্রি';
  static const String premium = 'প্রিমিয়াম';
  static const String subscribe = 'সাবস্ক্রাইব করুন';
  static const String unsubscribe = 'সাবস্ক্রিপশন বাতিল';
  static const String restoreSubscription = 'সাবস্ক্রিপশন পুনরুদ্ধার';
  static const String subscriptionPending = 'পেমেন্ট প্রক্রিয়াধীন';
  static const String subscriptionFailed = 'পেমেন্ট ব্যর্থ হয়েছে';

  // Misc
  static const String comingSoon = 'শীঘ্রই আসছে';
  static const String offline = 'আপনি অফলাইনে আছেন';

  // Notifications inbox
  static const String notifications = 'নোটিফিকেশন';
  static const String notificationsEyebrow = 'INBOX';
  static const String notificationsEmptyTitle = 'কোনো নোটিফিকেশন নেই';
  static const String notificationsEmptyHint =
      'গুরুত্বপূর্ণ সতর্কতা ও রিমাইন্ডার এখানে দেখা যাবে।';
  static const String notificationsMarkAllRead = 'সব পড়া হয়েছে';
  static const String notificationsUnreadDot = 'নতুন';
  // Settings hub
  static const String settingsTitle = 'সেটিংস';
  static const String settingsAccountSubtitle = 'অ্যাকাউন্ট ও ভাষা';
  static const String settingsEditProfile = 'প্রোফাইল সম্পাদনা';
  static const String settingsProfileNotSet = 'নাম সেট করা হয়নি';
  static const String settingsInboxTitle = 'নোটিফিকেশন ও সাবস্ক্রিপশন';
  static const String settingsInboxSubtitle = 'সব আপডেট দেখুন';
  static const String settingsSubscription = 'সাবস্ক্রিপশন প্ল্যান';
  static const String settingsPremiumActive = 'প্রিমিয়াম সক্রিয়';
  static const String settingsFreePlan = 'ফ্রি প্ল্যানে আছেন';
  static const String settingsUnknown = 'তথ্য নেই';
  static const String settingsHelpTitle = 'সহায়তা ও তথ্য';
  static const String settingsHelpSubtitle = 'অ্যাপ সম্পর্কে জানুন';
  static const String settingsHelp = 'সাহায্য ও প্রশ্নোত্তর';
  static const String settingsPrivacy = 'গোপনীয়তা নীতি';
  static const String settingsAbout = 'অ্যাপ সম্পর্কে';
  static const String settingsLogout = 'লগ আউট';
  static const String settingsLogoutSubtitle =
      'প্রোফাইল ও স্থানীয় তথ্য মুছে ফেলুন';
  static const String settingsLogoutConfirm =
      'প্রোফাইল ও স্থানীয় তথ্য মুছে যাবে। আপনি কি নিশ্চিত?';
  static const String settingsLogoutFailed = 'লগ আউট ব্যর্থ';
  static const String settingsPickLanguage = 'ভাষা নির্বাচন করুন';

  // Static info screens (help / privacy / subscription)
  static const String helpTitle = 'সাহায্য ও প্রশ্নোত্তর';
  static const String helpEyebrow = 'SUPPORT';
  static const String helpHeaderTitle = 'আমরা সাহায্য করতে প্রস্তুত';
  static const String helpHeaderSubtitle =
      'নিচের প্রশ্নোত্তরগুলো দেখুন অথবা সরাসরি যোগাযোগ করুন।';
  static const String helpFaqHeader = 'সচরাচর জিজ্ঞাসিত প্রশ্ন';
  static const String helpContactHeader = 'যোগাযোগ';
  static const String helpContactEmailLabel = 'ইমেইল';
  static const String helpContactPhoneLabel = 'হটলাইন';
  static const String helpContactWebsiteLabel = 'ওয়েবসাইট';
  static const String privacyTitle = 'গোপনীয়তা নীতি';
  static const String privacyEyebrow = 'PRIVACY';
  static const String privacyHeaderTitle =
      'আপনার গোপনীয়তা আমাদের কাছে গুরুত্বপূর্ণ';
  static const String privacyUpdatedOn = 'সর্বশেষ আপডেট: ১ জানুয়ারি ২০২৬';
  static const String privacySection1Title = 'আমরা কী তথ্য সংগ্রহ করি';
  static const String privacySection1Body =
      'আপনার প্রোফাইল তৈরির সময় আমরা নাম, ঠিকানা, জেলা, উপজেলা, জমির পরিমাণ ও '
      'প্রধান ফসলের তথ্য সংগ্রহ করি। ফসলের ছবি ও AI রোগ শনাক্তকরণের অনুরোধ সাময়িকভাবে '
      'আমাদের সার্ভারে পাঠানো হতে পারে, তবে চিকিৎসা সম্পন্ন হওয়ার পর মুছে ফেলা হয়।';
  static const String privacySection2Title = 'তথ্য কোথায় সংরক্ষণ হয়';
  static const String privacySection2Body =
      'আপনার মৌলিক প্রোফাইল ও খামার-সংক্রান্ত তথ্য আপনার মোবাইলে স্থানীয়ভাবে সংরক্ষিত থাকে। '
      'আবহাওয়া ও বাজারদরের তথ্য ক্যাশে রাখা হয় যাতে অফলাইনে দেখা যায়।';
  static const String privacySection3Title = 'তথ্য কার সাথে শেয়ার হয়';
  static const String privacySection3Body =
      'আপনার ব্যক্তিগত তথ্য আমরা তৃতীয় পক্ষের সাথে শেয়ার করি না। সমষ্টিগত ও বেনামী '
      'পরিসংখ্যান গবেষণা ও উন্নয়নের জন্য ব্যবহৃত হতে পারে।';
  static const String privacySection4Title = 'আপনার অধিকার';
  static const String privacySection4Body =
      'আপনি যেকোনো সময় প্রোফাইল সম্পাদনা বা মুছে ফেলতে পারবেন। সেটিংস > প্রোফাইল '
      'সম্পাদনা থেকে তথ্য পরিবর্তন করুন, অথবা লগ আউট বোতাম চেপে সম্পূর্ণ তথ্য মুছে ফেলুন।';
  static const String privacySection5Title = 'কুকিজ ও ট্র্যাকিং';
  static const String privacySection5Body =
      'আমরা কোনো বিজ্ঞাপন ট্র্যাকিং বা তৃতীয় পক্ষের কুকিজ ব্যবহার করি না। অ্যাপের কার্যক্ষমতা '
      'বজায় রাখতে শুধুমাত্র প্রয়োজনীয় স্থানীয় স্টোরেজ ব্যবহৃত হয়।';
  static const String privacySection6Title = 'যোগাযোগ';
  static const String privacySection6Body =
      'গোপনীয়তা সংক্রান্ত যেকোনো প্রশ্নের জন্য আমাদের সাথে যোগাযোগ করুন: '
      'support@krishiai.app';
  static const String privacyDisclaimer =
      'এই নীতি পরিবর্তন হতে পারে। গুরুত্বপূর্ণ পরিবর্তনের ক্ষেত্রে আপনাকে জানানো হবে।';
  static const String subscriptionTitle = 'সাবস্ক্রিপশন';
  static const String subscriptionEyebrow = 'PLAN';
  static const String subscriptionHeaderTitle =
      'আরও বেশি ফসল, আরও ভালো সিদ্ধান্ত';
  static const String subscriptionHeaderSubtitle =
      'প্রিমিয়াম সদস্যতায় AI সহকারী, বিস্তারিত আবহাওয়া, বাজার বিশ্লেষণ '
      'এবং আরও অনেক কিছু আনলক করুন।';
  static const String subscriptionCurrentLabel = 'বর্তমান প্ল্যান';
  static const String subscriptionCurrentPremium = 'প্রিমিয়াম সক্রিয়';
  static const String subscriptionCurrentFree = 'ফ্রি প্ল্যান';
  static const String subscriptionCurrentFreeDetail = 'বেসিক সুবিধা চালু আছে';
  static const String subscriptionExpirePrefix = 'মেয়াদ';
  static const String subscriptionPickHeader = 'প্ল্যান নির্বাচন করুন';
  static const String subscriptionCurrentPlanBadge = 'বর্তমান';
  static const String subscriptionActivePlan = 'সক্রিয় প্ল্যান';
  static const String subscriptionChoosePremium = 'প্রিমিয়াম নিন';
  static const String subscriptionChooseFree = 'ফ্রি চালিয়ে যান';
  static const String subscriptionLoading = 'প্ল্যান লোড হচ্ছে...';
  static const String subscriptionFaqHeader = 'প্রশ্ন আছে?';
  static const String subscriptionFaqBody =
      'প্ল্যান সংক্রান্ত প্রশ্ন? সাহায্য পেজে বিস্তারিত দেখুন অথবা সরাসরি যোগাযোগ করুন।';
  static const String subscriptionActivated = 'প্রিমিয়াম সক্রিয় হয়েছে';
  static const String subscriptionDowngraded = 'ফ্রি প্ল্যানে ফিরে এসেছেন';
  // ----- About screen -----
  static const String aboutTitle = 'অ্যাপ সম্পর্কে';
  static const String aboutEyebrow = 'ABOUT';
  static const String aboutHeaderTitle = 'কৃষি এআই';
  static const String aboutHeaderSubtitle =
      'বাংলাদেশের কৃষকদের জন্য একটি সহায়ক ডিজিটাল সঙ্গী।';
  static const String aboutAppNameLabel = 'অ্যাপের নাম';
  static const String aboutAppNameValue = 'কৃষি এআই';
  static const String aboutVersionLabel = 'সংস্করণ';
  static const String aboutVersionValue = '1.0.0 (build 1)';
  static const String aboutPlatformLabel = 'প্ল্যাটফর্ম';
  static const String aboutPlatformValue = 'Android, iOS, Web';
  static const String aboutLanguageLabel = 'ভাষা';
  static const String aboutLanguageValue = 'বাংলা, English';
  static const String aboutLicenseLabel = 'লাইসেন্স';
  static const String aboutLicenseValue = 'MIT';
  static const String aboutFeaturesHeader = 'বৈশিষ্ট্য';
  static const String aboutFeatureFarm = 'ফসল ও খামার ব্যবস্থাপনা';
  static const String aboutFeatureDisease = 'AI-চালিত রোগ শনাক্তকরণ';
  static const String aboutFeatureWeather =
      'স্থানীয় আবহাওয়া ও ৭ দিনের পূর্বাভাস';
  static const String aboutFeatureMarket = 'বাজারদর ও লাভ-ক্ষতির হিসাব';
  static const String aboutFeatureAssistant = 'AI সহকারী চ্যাট';
  static const String aboutCreditsHeader = 'স্বীকৃতি';
  static const String aboutCreditsBody =
      'এই অ্যাপটি বাংলাদেশের কৃষকদের কৃষিকাজে সহায়তা করার লক্ষ্যে নির্মিত। '
      'আবহাওয়া, বাজারদর ও রোগ শনাক্তকরণের তথ্য সর্বোচ্চ যত্নে সংগ্রহ করা হলেও '
      'চূড়ান্ত সিদ্ধান্তের আগে স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন।';
  static const String aboutCopyright = '© 2026 Krishi AI · All rights reserved';

  // ----- Profile screen -----
  static const String profileTitle = 'প্রোফাইল';
  static const String profileEyebrow = 'YOU';
  static const String profileHeaderSubtitle = 'আপনার খামার ও অ্যাকাউন্ট';
  static const String profileUnknownName = 'কৃষক ব্যবহারকারী';
  static const String profileLocationFallback = 'ঠিকানা সেট করা হয়নি';
  static const String profileCropNone = 'ফসল সেট করা হয়নি';
  static const String profileCropPrefix = 'ফসল';
  static const String profileExperiencePrefix = 'অভিজ্ঞতা';
  static const String profileExperienceUnit = 'বছর';
  static const String profileLandLabel = 'মোট জমি';
  static const String profileLandUnit = 'একর';
  static const String profileFarmsLabel = 'খামার';
  static const String profileFarmsUnit = 'টি';
  static const String profileCropsLabel = 'ফসল';
  static const String profileCropsUnit = 'টি';
  static const String profileAccount = 'অ্যাকাউন্ট';
  static const String profileAccountSubtitle = 'প্রোফাইল ও প্ল্যান';
  static const String profileEditSubtitle =
      'নাম, ঠিকানা ও ফসলের তথ্য আপডেট করুন';
  static const String profileNotificationsSubtitle = 'সব আপডেট এক জায়গায়';
  static const String profileSubscriptionSubtitle =
      'আপগ্রেড ও প্ল্যান পরিচালনা';
  static const String profileHelpLabel = 'সহায়তা';
  static const String profileHelpSubtitle = 'প্রশ্নোত্তর ও তথ্য';
  static const String profileFaqSubtitle = 'সচরাচর জিজ্ঞাসিত প্রশ্ন';
  static const String profilePrivacySubtitle = 'আপনার তথ্য কীভাবে সংরক্ষিত হয়';
  static const String profileAboutSubtitle = 'সংস্করণ ও কৃতজ্ঞতা';
  static const String profileLogout = 'লগ আউট';
  static const String profileLogoutSubtitle =
      'প্রোফাইল ও স্থানীয় তথ্য মুছে ফেলুন';
  static const String profileConfirmTitle = 'লগ আউট';
  static const String profileConfirmBody =
      'আপনার প্রোফাইল ও স্থানীয় তথ্য মুছে যাবে। আপনি কি নিশ্চিত?';
  static const String profileCancel = 'বাতিল';
  static const String profileConfirmLogout = 'লগ আউট';
  static const String profileLogoutFailedPrefix = 'লগ আউট ব্যর্থ';
  static const String profileLoadFailedPrefix = 'প্রোফাইল লোড করা যায়নি';
  static const String profileAppFooter = 'কৃষি এআই · Krishi AI v1.0.0';

  // ----- Edit profile screen -----
  static const String editTitle = 'প্রোফাইল সম্পাদনা';
  static const String editEyebrow = 'EDIT';
  static const String editHeaderSubtitle = 'আপনার পরিচয় ও খামারের তথ্য';
  static const String editIdentityTitle = 'ব্যক্তিগত তথ্য';
  static const String editIdentitySubtitle =
      'আপনার পরিচয় সংক্রান্ত প্রাথমিক তথ্য';
  static const String editFarmTitle = 'কৃষি তথ্য';
  static const String editFarmSubtitle = 'আপনার খামার ও ফসলের সারসংক্ষেপ';
  static const String editLanguageTitle = 'ভাষা';
  static const String editLanguageSubtitle = 'অ্যাপের জন্য পছন্দের ভাষা';
  static const String editNameRequired = 'নাম দিতে হবে';
  static const String editDistrictRequired = 'জেলা দিতে হবে';
  static const String editFarmSizeInvalid = 'সংখ্যা দিন';
  static const String editExperienceInvalid = 'অবাস্তব মান';
  static const String editSaved = 'প্রোফাইল আপডেট হয়েছে';
  static const String editSaveFailedPrefix = 'সংরক্ষণ ব্যর্থ';
  static const String editProfileNotCreatedHint =
      'প্রোফাইল এখনো তৈরি হয়নি। নিচের তথ্য পূরণ করে সংরক্ষণ করুন।';
  static const String editSave = 'পরিবর্তন সংরক্ষণ করুন';
  static const String editCancel = 'বাতিল';

  // ----- Generic error-state copy -----
  static const String errorTitle = 'কিছু একটা সমস্যা হয়েছে';
  static const String errorRetry = 'আবার চেষ্টা করুন';
}
