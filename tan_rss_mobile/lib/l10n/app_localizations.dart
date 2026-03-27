import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'TAN RSS'**
  String get appTitle;

  /// No description provided for @appTitleFull.
  ///
  /// In zh, this message translates to:
  /// **'TAN RSS Reader'**
  String get appTitleFull;

  /// No description provided for @navArticles.
  ///
  /// In zh, this message translates to:
  /// **'文章'**
  String get navArticles;

  /// No description provided for @navChannels.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get navChannels;

  /// No description provided for @navDiscovery.
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get navDiscovery;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @remove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// No description provided for @subscribe.
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get subscribe;

  /// No description provided for @unsubscribe.
  ///
  /// In zh, this message translates to:
  /// **'取消订阅'**
  String get unsubscribe;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get operationFailed;

  /// No description provided for @createFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建失败'**
  String get createFailed;

  /// No description provided for @updateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败'**
  String get updateFailed;

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get deleteFailed;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get saveFailed;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @noTitle.
  ///
  /// In zh, this message translates to:
  /// **'无标题'**
  String get noTitle;

  /// No description provided for @noContent.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get noContent;

  /// No description provided for @noDescription.
  ///
  /// In zh, this message translates to:
  /// **'暂无描述'**
  String get noDescription;

  /// No description provided for @comingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将推出'**
  String get comingSoon;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @aboutDescription.
  ///
  /// In zh, this message translates to:
  /// **'一个现代化的AI-RSS阅读器，支持AI摘要、智能翻译和优雅的阅读体验。'**
  String get aboutDescription;

  /// No description provided for @aboutSlogan.
  ///
  /// In zh, this message translates to:
  /// **'TAN 致力于为你的信息流带来清爽高效的阅读体验。'**
  String get aboutSlogan;

  /// No description provided for @aboutCoreFeatures.
  ///
  /// In zh, this message translates to:
  /// **'核心特性'**
  String get aboutCoreFeatures;

  /// No description provided for @aboutCoreFeaturesDesc.
  ///
  /// In zh, this message translates to:
  /// **'RSS订阅 · AI摘要 · 智能翻译 · 收藏管理'**
  String get aboutCoreFeaturesDesc;

  /// No description provided for @aboutTechStack.
  ///
  /// In zh, this message translates to:
  /// **'技术架构'**
  String get aboutTechStack;

  /// No description provided for @aboutTechStackDesc.
  ///
  /// In zh, this message translates to:
  /// **'Flutter 前端 | Python FastAPI 后端 | SQLite 数据库'**
  String get aboutTechStackDesc;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @register.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get register;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get usernameHint;

  /// No description provided for @usernameHelper.
  ///
  /// In zh, this message translates to:
  /// **'仅允许字母、数字、下划线(_)和连字符(-)，至少 3 个字符'**
  String get usernameHelper;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get passwordHint;

  /// No description provided for @passwordHelper.
  ///
  /// In zh, this message translates to:
  /// **'至少 6 个字符'**
  String get passwordHelper;

  /// No description provided for @emailOptional.
  ///
  /// In zh, this message translates to:
  /// **'邮箱（可选）'**
  String get emailOptional;

  /// No description provided for @emailHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入邮箱地址'**
  String get emailHint;

  /// No description provided for @loginWelcome.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来，请登录'**
  String get loginWelcome;

  /// No description provided for @createNewAccount.
  ///
  /// In zh, this message translates to:
  /// **'创建新账号'**
  String get createNewAccount;

  /// No description provided for @noAccount.
  ///
  /// In zh, this message translates to:
  /// **'没有账号？ '**
  String get noAccount;

  /// No description provided for @clickToRegister.
  ///
  /// In zh, this message translates to:
  /// **'点击注册'**
  String get clickToRegister;

  /// No description provided for @hasAccount.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？ '**
  String get hasAccount;

  /// No description provided for @clickToLogin.
  ///
  /// In zh, this message translates to:
  /// **'点击登录'**
  String get clickToLogin;

  /// No description provided for @loginSuccess.
  ///
  /// In zh, this message translates to:
  /// **'登录成功'**
  String get loginSuccess;

  /// No description provided for @loginSuccessWelcome.
  ///
  /// In zh, this message translates to:
  /// **'登录成功，欢迎回来！'**
  String get loginSuccessWelcome;

  /// No description provided for @registerSuccess.
  ///
  /// In zh, this message translates to:
  /// **'注册成功，欢迎加入！'**
  String get registerSuccess;

  /// No description provided for @usernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get usernameRequired;

  /// No description provided for @usernameMinChars.
  ///
  /// In zh, this message translates to:
  /// **'用户名至少需要 3 个字符'**
  String get usernameMinChars;

  /// No description provided for @usernameInvalidChars.
  ///
  /// In zh, this message translates to:
  /// **'用户名只能包含字母、数字、_ 和 -'**
  String get usernameInvalidChars;

  /// No description provided for @emailFormatInvalid.
  ///
  /// In zh, this message translates to:
  /// **'邮箱格式不正确'**
  String get emailFormatInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get passwordRequired;

  /// No description provided for @passwordMinChars.
  ///
  /// In zh, this message translates to:
  /// **'密码至少需要 6 个字符'**
  String get passwordMinChars;

  /// No description provided for @passwordLengthError.
  ///
  /// In zh, this message translates to:
  /// **'密码长度不能少于 6 位'**
  String get passwordLengthError;

  /// No description provided for @serverAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// No description provided for @serverAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器地址'**
  String get serverAddressHint;

  /// No description provided for @serverAddressMustHttp.
  ///
  /// In zh, this message translates to:
  /// **'地址必须以 http 或 https 开头'**
  String get serverAddressMustHttp;

  /// No description provided for @collapseConfig.
  ///
  /// In zh, this message translates to:
  /// **'收起配置'**
  String get collapseConfig;

  /// No description provided for @serverConfig.
  ///
  /// In zh, this message translates to:
  /// **'服务器配置'**
  String get serverConfig;

  /// No description provided for @myChannels.
  ///
  /// In zh, this message translates to:
  /// **'我的频道'**
  String get myChannels;

  /// No description provided for @noSubscribedChannels.
  ///
  /// In zh, this message translates to:
  /// **'暂无订阅的频道'**
  String get noSubscribedChannels;

  /// No description provided for @goToChannelSquare.
  ///
  /// In zh, this message translates to:
  /// **'去频道广场逛逛'**
  String get goToChannelSquare;

  /// No description provided for @starred.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get starred;

  /// No description provided for @noStarredArticles.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏的文章'**
  String get noStarredArticles;

  /// No description provided for @renameChannel.
  ///
  /// In zh, this message translates to:
  /// **'重命名频道'**
  String get renameChannel;

  /// No description provided for @newName.
  ///
  /// In zh, this message translates to:
  /// **'新名称'**
  String get newName;

  /// No description provided for @deleteChannel.
  ///
  /// In zh, this message translates to:
  /// **'删除频道'**
  String get deleteChannel;

  /// No description provided for @deleteChannelConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除该频道？只移除频道与订阅关系，不会删除订阅源。'**
  String get deleteChannelConfirm;

  /// No description provided for @addFeedToChannel.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅到频道'**
  String get addFeedToChannel;

  /// No description provided for @rssAtomUrl.
  ///
  /// In zh, this message translates to:
  /// **'RSS/Atom URL'**
  String get rssAtomUrl;

  /// No description provided for @titleOptional.
  ///
  /// In zh, this message translates to:
  /// **'标题（可选）'**
  String get titleOptional;

  /// No description provided for @createNewFeed.
  ///
  /// In zh, this message translates to:
  /// **'新增订阅源'**
  String get createNewFeed;

  /// No description provided for @url.
  ///
  /// In zh, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @editFeed.
  ///
  /// In zh, this message translates to:
  /// **'编辑订阅源'**
  String get editFeed;

  /// No description provided for @title.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get title;

  /// No description provided for @updateIntervalMinutes.
  ///
  /// In zh, this message translates to:
  /// **'更新间隔（分钟）'**
  String get updateIntervalMinutes;

  /// No description provided for @defaultInterval.
  ///
  /// In zh, this message translates to:
  /// **'默认（15分钟）'**
  String get defaultInterval;

  /// No description provided for @minutes5.
  ///
  /// In zh, this message translates to:
  /// **'5分钟'**
  String get minutes5;

  /// No description provided for @minutes10.
  ///
  /// In zh, this message translates to:
  /// **'10分钟'**
  String get minutes10;

  /// No description provided for @minutes15.
  ///
  /// In zh, this message translates to:
  /// **'15分钟'**
  String get minutes15;

  /// No description provided for @minutes30.
  ///
  /// In zh, this message translates to:
  /// **'30分钟'**
  String get minutes30;

  /// No description provided for @hour1.
  ///
  /// In zh, this message translates to:
  /// **'1小时'**
  String get hour1;

  /// No description provided for @hours2.
  ///
  /// In zh, this message translates to:
  /// **'2小时'**
  String get hours2;

  /// No description provided for @hours6.
  ///
  /// In zh, this message translates to:
  /// **'6小时'**
  String get hours6;

  /// No description provided for @hours12.
  ///
  /// In zh, this message translates to:
  /// **'12小时'**
  String get hours12;

  /// No description provided for @hours24.
  ///
  /// In zh, this message translates to:
  /// **'24小时'**
  String get hours24;

  /// No description provided for @unsubscribeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定取消订阅「{title}」？\n取消后将不再收到该订阅源的更新。'**
  String unsubscribeConfirm(Object title);

  /// No description provided for @thinkAgain.
  ///
  /// In zh, this message translates to:
  /// **'再想想'**
  String get thinkAgain;

  /// No description provided for @confirmUnsubscribe.
  ///
  /// In zh, this message translates to:
  /// **'确定取消'**
  String get confirmUnsubscribe;

  /// No description provided for @unsubscribed.
  ///
  /// In zh, this message translates to:
  /// **'已取消订阅'**
  String get unsubscribed;

  /// No description provided for @allUnread.
  ///
  /// In zh, this message translates to:
  /// **'所有未读'**
  String get allUnread;

  /// No description provided for @unreadCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 未读'**
  String unreadCount(Object count);

  /// No description provided for @addFeedHere.
  ///
  /// In zh, this message translates to:
  /// **'在此频道添加订阅'**
  String get addFeedHere;

  /// No description provided for @renameChannelMenu.
  ///
  /// In zh, this message translates to:
  /// **'重命名频道'**
  String get renameChannelMenu;

  /// No description provided for @deleteChannelMenu.
  ///
  /// In zh, this message translates to:
  /// **'删除频道'**
  String get deleteChannelMenu;

  /// No description provided for @noFeedsClickToAdd.
  ///
  /// In zh, this message translates to:
  /// **'暂无订阅源，点击右上角 + 添加'**
  String get noFeedsClickToAdd;

  /// No description provided for @addSubscriptionSource.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅源'**
  String get addSubscriptionSource;

  /// No description provided for @subscriptionLink.
  ///
  /// In zh, this message translates to:
  /// **'订阅链接'**
  String get subscriptionLink;

  /// No description provided for @subscriptionLinkHint.
  ///
  /// In zh, this message translates to:
  /// **'https://example.com/feed.xml'**
  String get subscriptionLinkHint;

  /// No description provided for @paste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get paste;

  /// No description provided for @enterSubscriptionLink.
  ///
  /// In zh, this message translates to:
  /// **'请输入订阅链接'**
  String get enterSubscriptionLink;

  /// No description provided for @linkMustHttp.
  ///
  /// In zh, this message translates to:
  /// **'链接必须以 http:// 或 https:// 开头'**
  String get linkMustHttp;

  /// No description provided for @addingContent.
  ///
  /// In zh, this message translates to:
  /// **'正在添加并获取内容...'**
  String get addingContent;

  /// No description provided for @addSubscriptionSourceButton.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅源'**
  String get addSubscriptionSourceButton;

  /// No description provided for @supportedSources.
  ///
  /// In zh, this message translates to:
  /// **'支持的内容来源'**
  String get supportedSources;

  /// No description provided for @blogWebsite.
  ///
  /// In zh, this message translates to:
  /// **'博客 / 网站'**
  String get blogWebsite;

  /// No description provided for @other.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get other;

  /// No description provided for @quickAddExamples.
  ///
  /// In zh, this message translates to:
  /// **'快速添加示例'**
  String get quickAddExamples;

  /// No description provided for @subscriptionAddedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'订阅源添加成功'**
  String get subscriptionAddedSuccess;

  /// No description provided for @fetchingInBackground.
  ///
  /// In zh, this message translates to:
  /// **'正在后台获取最新内容...'**
  String get fetchingInBackground;

  /// No description provided for @reading.
  ///
  /// In zh, this message translates to:
  /// **'阅读'**
  String get reading;

  /// No description provided for @aiSummary.
  ///
  /// In zh, this message translates to:
  /// **'AI 摘要'**
  String get aiSummary;

  /// No description provided for @translateTitleButton.
  ///
  /// In zh, this message translates to:
  /// **'翻译标题'**
  String get translateTitleButton;

  /// No description provided for @translateContent.
  ///
  /// In zh, this message translates to:
  /// **'翻译正文'**
  String get translateContent;

  /// No description provided for @deepDive.
  ///
  /// In zh, this message translates to:
  /// **'深度解读'**
  String get deepDive;

  /// No description provided for @showTranslatedTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示翻译标题'**
  String get showTranslatedTitle;

  /// No description provided for @showTranslatedContent.
  ///
  /// In zh, this message translates to:
  /// **'显示翻译正文'**
  String get showTranslatedContent;

  /// No description provided for @aiDeepDive.
  ///
  /// In zh, this message translates to:
  /// **'AI 深度解读'**
  String get aiDeepDive;

  /// No description provided for @aiSummaryFailed.
  ///
  /// In zh, this message translates to:
  /// **'AI 摘要失败：'**
  String get aiSummaryFailed;

  /// No description provided for @titleTranslationFailed.
  ///
  /// In zh, this message translates to:
  /// **'标题翻译失败：'**
  String get titleTranslationFailed;

  /// No description provided for @contentTranslationFailed.
  ///
  /// In zh, this message translates to:
  /// **'正文翻译失败：'**
  String get contentTranslationFailed;

  /// No description provided for @deepDiveFailed.
  ///
  /// In zh, this message translates to:
  /// **'AI 深度解读失败：'**
  String get deepDiveFailed;

  /// No description provided for @markRead.
  ///
  /// In zh, this message translates to:
  /// **'标记已读'**
  String get markRead;

  /// No description provided for @markUnread.
  ///
  /// In zh, this message translates to:
  /// **'标记未读'**
  String get markUnread;

  /// No description provided for @star.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get star;

  /// No description provided for @unstar.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get unstar;

  /// No description provided for @addToBatch.
  ///
  /// In zh, this message translates to:
  /// **'加入批量'**
  String get addToBatch;

  /// No description provided for @translateTitle.
  ///
  /// In zh, this message translates to:
  /// **'翻译标题'**
  String get translateTitle;

  /// No description provided for @articlesSection.
  ///
  /// In zh, this message translates to:
  /// **'文章'**
  String get articlesSection;

  /// No description provided for @batchOperation.
  ///
  /// In zh, this message translates to:
  /// **'批量操作'**
  String get batchOperation;

  /// No description provided for @unread.
  ///
  /// In zh, this message translates to:
  /// **'未读'**
  String get unread;

  /// No description provided for @highQuality.
  ///
  /// In zh, this message translates to:
  /// **'精选'**
  String get highQuality;

  /// No description provided for @starredFilter.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get starredFilter;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String selectedCount(Object count);

  /// No description provided for @batchStar.
  ///
  /// In zh, this message translates to:
  /// **'批量收藏'**
  String get batchStar;

  /// No description provided for @batchUnstar.
  ///
  /// In zh, this message translates to:
  /// **'批量取消'**
  String get batchUnstar;

  /// No description provided for @deselect.
  ///
  /// In zh, this message translates to:
  /// **'取消选择'**
  String get deselect;

  /// No description provided for @noArticlesMatch.
  ///
  /// In zh, this message translates to:
  /// **'当前条件下没有文章'**
  String get noArticlesMatch;

  /// No description provided for @aiBriefing.
  ///
  /// In zh, this message translates to:
  /// **'AI 简报'**
  String get aiBriefing;

  /// No description provided for @noArticlesForBriefing.
  ///
  /// In zh, this message translates to:
  /// **'当前没有文章可供生成简报'**
  String get noArticlesForBriefing;

  /// No description provided for @trendsTab.
  ///
  /// In zh, this message translates to:
  /// **'话题趋势'**
  String get trendsTab;

  /// No description provided for @semanticSearchTab.
  ///
  /// In zh, this message translates to:
  /// **'语义搜索'**
  String get semanticSearchTab;

  /// No description provided for @majorEvents.
  ///
  /// In zh, this message translates to:
  /// **'重大事件'**
  String get majorEvents;

  /// No description provided for @sourceHighlights.
  ///
  /// In zh, this message translates to:
  /// **'信息源高光'**
  String get sourceHighlights;

  /// No description provided for @deepAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'深度解读'**
  String get deepAnalysis;

  /// No description provided for @integratedToDailyBriefing.
  ///
  /// In zh, this message translates to:
  /// **'已集成至每日简报'**
  String get integratedToDailyBriefing;

  /// No description provided for @aiDailyBriefing.
  ///
  /// In zh, this message translates to:
  /// **'AI 每日简报'**
  String get aiDailyBriefing;

  /// No description provided for @dailyBriefingDesc.
  ///
  /// In zh, this message translates to:
  /// **'阅读所有频道的精华总结'**
  String get dailyBriefingDesc;

  /// No description provided for @noUnreadForBriefing.
  ///
  /// In zh, this message translates to:
  /// **'当前没有未读文章可供生成简报'**
  String get noUnreadForBriefing;

  /// No description provided for @getArticlesFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取文章失败'**
  String get getArticlesFailed;

  /// No description provided for @timeRange.
  ///
  /// In zh, this message translates to:
  /// **'时间范围: '**
  String get timeRange;

  /// No description provided for @last24Hours.
  ///
  /// In zh, this message translates to:
  /// **'最近 24 小时'**
  String get last24Hours;

  /// No description provided for @last3Days.
  ///
  /// In zh, this message translates to:
  /// **'最近 3 天'**
  String get last3Days;

  /// No description provided for @lastWeek.
  ///
  /// In zh, this message translates to:
  /// **'最近一周'**
  String get lastWeek;

  /// No description provided for @last1Month.
  ///
  /// In zh, this message translates to:
  /// **'最近 1 个月'**
  String get last1Month;

  /// No description provided for @last3Months.
  ///
  /// In zh, this message translates to:
  /// **'最近 3 个月'**
  String get last3Months;

  /// No description provided for @noTrendTopics.
  ///
  /// In zh, this message translates to:
  /// **'该时间段内未发现趋势话题'**
  String get noTrendTopics;

  /// No description provided for @articleCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 篇'**
  String articleCount(Object count);

  /// No description provided for @moreArticles.
  ///
  /// In zh, this message translates to:
  /// **'+ {count} 篇更多'**
  String moreArticles(Object count);

  /// No description provided for @smartAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'智能分析'**
  String get smartAnalysis;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'输入问题或描述...'**
  String get searchHint;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败'**
  String get searchFailed;

  /// No description provided for @noResults.
  ///
  /// In zh, this message translates to:
  /// **'未找到相关结果'**
  String get noResults;

  /// No description provided for @inputKeywordsToSearch.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词开始搜索'**
  String get inputKeywordsToSearch;

  /// No description provided for @publishTime.
  ///
  /// In zh, this message translates to:
  /// **'发布时间: '**
  String get publishTime;

  /// No description provided for @openArticleFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开文章失败'**
  String get openArticleFailed;

  /// No description provided for @generatingAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'正在生成智能分析报告...'**
  String get generatingAnalysis;

  /// No description provided for @analysisFailed.
  ///
  /// In zh, this message translates to:
  /// **'分析失败'**
  String get analysisFailed;

  /// No description provided for @noAnalysisData.
  ///
  /// In zh, this message translates to:
  /// **'暂无分析数据'**
  String get noAnalysisData;

  /// No description provided for @smartTrendAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'智能趋势分析'**
  String get smartTrendAnalysis;

  /// No description provided for @trendPrediction.
  ///
  /// In zh, this message translates to:
  /// **'趋势预测'**
  String get trendPrediction;

  /// No description provided for @keywords.
  ///
  /// In zh, this message translates to:
  /// **'关键词:'**
  String get keywords;

  /// No description provided for @sentiment.
  ///
  /// In zh, this message translates to:
  /// **'情感倾向:'**
  String get sentiment;

  /// No description provided for @sentimentPositive.
  ///
  /// In zh, this message translates to:
  /// **'正面'**
  String get sentimentPositive;

  /// No description provided for @sentimentNegative.
  ///
  /// In zh, this message translates to:
  /// **'负面'**
  String get sentimentNegative;

  /// No description provided for @sentimentNeutral.
  ///
  /// In zh, this message translates to:
  /// **'中性'**
  String get sentimentNeutral;

  /// No description provided for @summary.
  ///
  /// In zh, this message translates to:
  /// **'摘要'**
  String get summary;

  /// No description provided for @eventTimeline.
  ///
  /// In zh, this message translates to:
  /// **'事件脉络'**
  String get eventTimeline;

  /// No description provided for @channelSquare.
  ///
  /// In zh, this message translates to:
  /// **'频道广场'**
  String get channelSquare;

  /// No description provided for @searchChannels.
  ///
  /// In zh, this message translates to:
  /// **'搜索频道'**
  String get searchChannels;

  /// No description provided for @discover.
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get discover;

  /// No description provided for @mySubscriptions.
  ///
  /// In zh, this message translates to:
  /// **'我的订阅'**
  String get mySubscriptions;

  /// No description provided for @curatedPacks.
  ///
  /// In zh, this message translates to:
  /// **'精选包'**
  String get curatedPacks;

  /// No description provided for @noChannelsFound.
  ///
  /// In zh, this message translates to:
  /// **'暂无频道'**
  String get noChannelsFound;

  /// No description provided for @noSubscriptions.
  ///
  /// In zh, this message translates to:
  /// **'暂无订阅'**
  String get noSubscriptions;

  /// No description provided for @subscribed.
  ///
  /// In zh, this message translates to:
  /// **'已订阅'**
  String get subscribed;

  /// No description provided for @subscribedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已订阅 {name}'**
  String subscribedSuccess(Object name);

  /// No description provided for @subscribeFailed.
  ///
  /// In zh, this message translates to:
  /// **'订阅失败'**
  String get subscribeFailed;

  /// No description provided for @unsubscribeChannel.
  ///
  /// In zh, this message translates to:
  /// **'取消订阅'**
  String get unsubscribeChannel;

  /// No description provided for @unsubscribeChannelConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定取消订阅 \"{name}\" 吗？'**
  String unsubscribeChannelConfirm(Object name);

  /// No description provided for @unsubscribedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已取消订阅 {name}'**
  String unsubscribedSuccess(Object name);

  /// No description provided for @unsubscribeFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消订阅失败'**
  String get unsubscribeFailed;

  /// No description provided for @noPacks.
  ///
  /// In zh, this message translates to:
  /// **'暂无精选包'**
  String get noPacks;

  /// No description provided for @clickToCreatePack.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角创建属于你的频道合集'**
  String get clickToCreatePack;

  /// No description provided for @oneClickSubscribe.
  ///
  /// In zh, this message translates to:
  /// **'一键订阅'**
  String get oneClickSubscribe;

  /// No description provided for @channelCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个频道'**
  String channelCount(Object count);

  /// No description provided for @installCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次安装'**
  String installCount(Object count);

  /// No description provided for @includedChannels.
  ///
  /// In zh, this message translates to:
  /// **'包含频道:'**
  String get includedChannels;

  /// No description provided for @moreChannels.
  ///
  /// In zh, this message translates to:
  /// **'等 {count} 个频道'**
  String moreChannels(Object count);

  /// No description provided for @installedPack.
  ///
  /// In zh, this message translates to:
  /// **'已安装 \"{name}\"，新增 {added} 个频道订阅'**
  String installedPack(Object added, Object name);

  /// No description provided for @skippedChannels.
  ///
  /// In zh, this message translates to:
  /// **'，跳过 {skipped} 个已订阅'**
  String skippedChannels(Object skipped);

  /// No description provided for @installFailed.
  ///
  /// In zh, this message translates to:
  /// **'安装失败'**
  String get installFailed;

  /// No description provided for @createPack.
  ///
  /// In zh, this message translates to:
  /// **'创建精选包'**
  String get createPack;

  /// No description provided for @packNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'精选包名称 *'**
  String get packNameRequired;

  /// No description provided for @packNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：AI 资讯合集'**
  String get packNameHint;

  /// No description provided for @packDesc.
  ///
  /// In zh, this message translates to:
  /// **'描述（可选）'**
  String get packDesc;

  /// No description provided for @includedChannelsSection.
  ///
  /// In zh, this message translates to:
  /// **'包含的频道'**
  String get includedChannelsSection;

  /// No description provided for @addChannels.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addChannels;

  /// No description provided for @noChannelsSelected.
  ///
  /// In zh, this message translates to:
  /// **'暂未选择任何频道'**
  String get noChannelsSelected;

  /// No description provided for @selectChannels.
  ///
  /// In zh, this message translates to:
  /// **'选择要加入的频道'**
  String get selectChannels;

  /// No description provided for @noSubscribedChannelsForPack.
  ///
  /// In zh, this message translates to:
  /// **'暂无订阅的频道，请先去订阅一些吧'**
  String get noSubscribedChannelsForPack;

  /// No description provided for @packNameRequiredMsg.
  ///
  /// In zh, this message translates to:
  /// **'请输入包名称'**
  String get packNameRequiredMsg;

  /// No description provided for @selectAtLeastOneChannel.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一个频道'**
  String get selectAtLeastOneChannel;

  /// No description provided for @createSuccess.
  ///
  /// In zh, this message translates to:
  /// **'创建成功'**
  String get createSuccess;

  /// No description provided for @noArticlesForAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'暂无文章可供分析'**
  String get noArticlesForAnalysis;

  /// No description provided for @channelLinkCopied.
  ///
  /// In zh, this message translates to:
  /// **'频道链接已复制'**
  String get channelLinkCopied;

  /// No description provided for @getLatestContent.
  ///
  /// In zh, this message translates to:
  /// **'获取最新内容'**
  String get getLatestContent;

  /// No description provided for @markAllAsRead.
  ///
  /// In zh, this message translates to:
  /// **'全部设为已读'**
  String get markAllAsRead;

  /// No description provided for @viewSources.
  ///
  /// In zh, this message translates to:
  /// **'查看信息源'**
  String get viewSources;

  /// No description provided for @shareChannel.
  ///
  /// In zh, this message translates to:
  /// **'分享频道'**
  String get shareChannel;

  /// No description provided for @noArticles.
  ///
  /// In zh, this message translates to:
  /// **'暂无文章'**
  String get noArticles;

  /// No description provided for @newContentCount.
  ///
  /// In zh, this message translates to:
  /// **'获取到 {count} 条新内容'**
  String newContentCount(Object count);

  /// No description provided for @alreadyLatest.
  ///
  /// In zh, this message translates to:
  /// **'已是最新内容'**
  String get alreadyLatest;

  /// No description provided for @refreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'刷新失败'**
  String get refreshFailed;

  /// No description provided for @markedReadCount.
  ///
  /// In zh, this message translates to:
  /// **'已将 {count} 篇文章设为已读'**
  String markedReadCount(Object count);

  /// No description provided for @noUnreadArticles.
  ///
  /// In zh, this message translates to:
  /// **'没有未读文章'**
  String get noUnreadArticles;

  /// No description provided for @submittedBy.
  ///
  /// In zh, this message translates to:
  /// **'submitted by {author}'**
  String submittedBy(Object author);

  /// No description provided for @getLatestContentButton.
  ///
  /// In zh, this message translates to:
  /// **'获取最新内容'**
  String get getLatestContentButton;

  /// No description provided for @channelManagement.
  ///
  /// In zh, this message translates to:
  /// **'频道管理'**
  String get channelManagement;

  /// No description provided for @noChannels.
  ///
  /// In zh, this message translates to:
  /// **'暂无频道'**
  String get noChannels;

  /// No description provided for @clickPlusToCreateChannel.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角 + 创建新频道'**
  String get clickPlusToCreateChannel;

  /// No description provided for @createChannel.
  ///
  /// In zh, this message translates to:
  /// **'创建频道'**
  String get createChannel;

  /// No description provided for @channelName.
  ///
  /// In zh, this message translates to:
  /// **'频道名称'**
  String get channelName;

  /// No description provided for @descriptionOptional.
  ///
  /// In zh, this message translates to:
  /// **'描述（可选）'**
  String get descriptionOptional;

  /// No description provided for @channelCreated.
  ///
  /// In zh, this message translates to:
  /// **'频道创建成功'**
  String get channelCreated;

  /// No description provided for @editChannel.
  ///
  /// In zh, this message translates to:
  /// **'编辑频道'**
  String get editChannel;

  /// No description provided for @iconUrlOptional.
  ///
  /// In zh, this message translates to:
  /// **'图标URL（可选）'**
  String get iconUrlOptional;

  /// No description provided for @coverUrlOptional.
  ///
  /// In zh, this message translates to:
  /// **'封面URL（可选）'**
  String get coverUrlOptional;

  /// No description provided for @categoryOptional.
  ///
  /// In zh, this message translates to:
  /// **'分类（可选）'**
  String get categoryOptional;

  /// No description provided for @noCategory.
  ///
  /// In zh, this message translates to:
  /// **'无分类'**
  String get noCategory;

  /// No description provided for @publicChannel.
  ///
  /// In zh, this message translates to:
  /// **'公开频道'**
  String get publicChannel;

  /// No description provided for @publicChannelVisible.
  ///
  /// In zh, this message translates to:
  /// **'所有用户可见'**
  String get publicChannelVisible;

  /// No description provided for @privateChannelVisible.
  ///
  /// In zh, this message translates to:
  /// **'仅自己可见'**
  String get privateChannelVisible;

  /// No description provided for @channelUpdated.
  ///
  /// In zh, this message translates to:
  /// **'频道更新成功'**
  String get channelUpdated;

  /// No description provided for @deleteChannelConfirmAdmin.
  ///
  /// In zh, this message translates to:
  /// **'确定删除频道 \"{name}\" 吗？'**
  String deleteChannelConfirmAdmin(Object name);

  /// No description provided for @channelDeleted.
  ///
  /// In zh, this message translates to:
  /// **'频道已删除'**
  String get channelDeleted;

  /// No description provided for @manageSources.
  ///
  /// In zh, this message translates to:
  /// **'管理订阅源'**
  String get manageSources;

  /// No description provided for @channelSources.
  ///
  /// In zh, this message translates to:
  /// **'{channelName} - 订阅源'**
  String channelSources(Object channelName);

  /// No description provided for @noSources.
  ///
  /// In zh, this message translates to:
  /// **'暂无订阅源'**
  String get noSources;

  /// No description provided for @clickPlusToAddSource.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角 + 添加订阅源'**
  String get clickPlusToAddSource;

  /// No description provided for @noUserFeeds.
  ///
  /// In zh, this message translates to:
  /// **'您还没有订阅任何订阅源'**
  String get noUserFeeds;

  /// No description provided for @allFeedsAdded.
  ///
  /// In zh, this message translates to:
  /// **'所有订阅源已添加到此频道'**
  String get allFeedsAdded;

  /// No description provided for @addSource.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅源'**
  String get addSource;

  /// No description provided for @sourceAdded.
  ///
  /// In zh, this message translates to:
  /// **'订阅源已添加'**
  String get sourceAdded;

  /// No description provided for @addFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加失败'**
  String get addFailed;

  /// No description provided for @removeSource.
  ///
  /// In zh, this message translates to:
  /// **'移除订阅源'**
  String get removeSource;

  /// No description provided for @removeSourceConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定从频道中移除 \"{name}\" 吗？'**
  String removeSourceConfirm(Object name);

  /// No description provided for @sourceRemoved.
  ///
  /// In zh, this message translates to:
  /// **'订阅源已移除'**
  String get sourceRemoved;

  /// No description provided for @removeFailed.
  ///
  /// In zh, this message translates to:
  /// **'移除失败'**
  String get removeFailed;

  /// No description provided for @platformAdmin.
  ///
  /// In zh, this message translates to:
  /// **'平台管理中心'**
  String get platformAdmin;

  /// No description provided for @myChannelsAdmin.
  ///
  /// In zh, this message translates to:
  /// **'我的频道'**
  String get myChannelsAdmin;

  /// No description provided for @channelsTab.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get channelsTab;

  /// No description provided for @feedsTab.
  ///
  /// In zh, this message translates to:
  /// **'订阅源'**
  String get feedsTab;

  /// No description provided for @noChannelAdmin.
  ///
  /// In zh, this message translates to:
  /// **'暂无频道'**
  String get noChannelAdmin;

  /// No description provided for @clickToCreateFirstChannel.
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮创建第一个频道'**
  String get clickToCreateFirstChannel;

  /// No description provided for @noPersonalChannels.
  ///
  /// In zh, this message translates to:
  /// **'暂无个人频道'**
  String get noPersonalChannels;

  /// No description provided for @platformChannels.
  ///
  /// In zh, this message translates to:
  /// **'平台频道'**
  String get platformChannels;

  /// No description provided for @personalChannels.
  ///
  /// In zh, this message translates to:
  /// **'个人频道'**
  String get personalChannels;

  /// No description provided for @createChannelAdmin.
  ///
  /// In zh, this message translates to:
  /// **'创建频道'**
  String get createChannelAdmin;

  /// No description provided for @publicChannelOtherUsers.
  ///
  /// In zh, this message translates to:
  /// **'其他用户可发现并订阅'**
  String get publicChannelOtherUsers;

  /// No description provided for @privateChannelSelf.
  ///
  /// In zh, this message translates to:
  /// **'仅自己可见'**
  String get privateChannelSelf;

  /// No description provided for @deleteChannelAdmin.
  ///
  /// In zh, this message translates to:
  /// **'删除频道'**
  String get deleteChannelAdmin;

  /// No description provided for @deleteChannelAdminConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 \"{name}\" 吗？这不会删除其包含的信息源。'**
  String deleteChannelAdminConfirm(Object name);

  /// No description provided for @channelDeletedAdmin.
  ///
  /// In zh, this message translates to:
  /// **'频道已删除'**
  String get channelDeletedAdmin;

  /// No description provided for @noSourcesAdmin.
  ///
  /// In zh, this message translates to:
  /// **'暂无订阅源，点击 + 添加'**
  String get noSourcesAdmin;

  /// No description provided for @sourcesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个订阅源'**
  String sourcesCount(Object count);

  /// No description provided for @addSourceAdmin.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅源'**
  String get addSourceAdmin;

  /// No description provided for @sourceAddedAdmin.
  ///
  /// In zh, this message translates to:
  /// **'订阅源添加成功'**
  String get sourceAddedAdmin;

  /// No description provided for @addFailedAdmin.
  ///
  /// In zh, this message translates to:
  /// **'添加失败'**
  String get addFailedAdmin;

  /// No description provided for @removeSourceAdmin.
  ///
  /// In zh, this message translates to:
  /// **'移除订阅源'**
  String get removeSourceAdmin;

  /// No description provided for @removeSourceAdminConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要移除「{name}」吗？'**
  String removeSourceAdminConfirm(Object name);

  /// No description provided for @removeFailedAdmin.
  ///
  /// In zh, this message translates to:
  /// **'移除失败'**
  String get removeFailedAdmin;

  /// No description provided for @noFeedsAdmin.
  ///
  /// In zh, this message translates to:
  /// **'暂无订阅源'**
  String get noFeedsAdmin;

  /// No description provided for @addFeedAdmin.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅源'**
  String get addFeedAdmin;

  /// No description provided for @deleteFeed.
  ///
  /// In zh, this message translates to:
  /// **'删除订阅源'**
  String get deleteFeed;

  /// No description provided for @deleteFeedConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除订阅源「{title}」吗？'**
  String deleteFeedConfirm(Object title);

  /// No description provided for @feedDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get feedDeleted;

  /// No description provided for @deleteFeedFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get deleteFeedFailed;

  /// No description provided for @addButton.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅源'**
  String get addButton;

  /// No description provided for @changelog.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get changelog;

  /// No description provided for @changelogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看最新版本的改进内容'**
  String get changelogSubtitle;

  /// No description provided for @membershipCenter.
  ///
  /// In zh, this message translates to:
  /// **'会员中心'**
  String get membershipCenter;

  /// No description provided for @membershipSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'解锁高级 AI 功能与特权'**
  String get membershipSubtitle;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get account;

  /// No description provided for @accountSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本地, 云端同步'**
  String get accountSubtitle;

  /// No description provided for @colorAndStyle.
  ///
  /// In zh, this message translates to:
  /// **'颜色和样式'**
  String get colorAndStyle;

  /// No description provided for @colorAndStyleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'主题, 文章样式'**
  String get colorAndStyleSubtitle;

  /// No description provided for @interaction.
  ///
  /// In zh, this message translates to:
  /// **'交互'**
  String get interaction;

  /// No description provided for @interactionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'手势操作, 启动页面'**
  String get interactionSubtitle;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'界面、AI、翻译'**
  String get languageSubtitle;

  /// No description provided for @aiFeatures.
  ///
  /// In zh, this message translates to:
  /// **'AI功能'**
  String get aiFeatures;

  /// No description provided for @aiFeaturesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 提供商, AI 指令'**
  String get aiFeaturesSubtitle;

  /// No description provided for @highlightSettings.
  ///
  /// In zh, this message translates to:
  /// **'高亮设置'**
  String get highlightSettings;

  /// No description provided for @highlightSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理文章中的关键词高亮'**
  String get highlightSubtitle;

  /// No description provided for @ttsSettings.
  ///
  /// In zh, this message translates to:
  /// **'TTS设置'**
  String get ttsSettings;

  /// No description provided for @ttsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'语音、语言设置'**
  String get ttsSubtitle;

  /// No description provided for @syncSettings.
  ///
  /// In zh, this message translates to:
  /// **'同步设置'**
  String get syncSettings;

  /// No description provided for @syncSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自动刷新, API 地址配置'**
  String get syncSubtitle;

  /// No description provided for @importExport.
  ///
  /// In zh, this message translates to:
  /// **'导入/导出'**
  String get importExport;

  /// No description provided for @importExportSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'订阅源, App 设置'**
  String get importExportSubtitle;

  /// No description provided for @platformAdminCenter.
  ///
  /// In zh, this message translates to:
  /// **'平台管理中心'**
  String get platformAdminCenter;

  /// No description provided for @platformAdminSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'全局频道、分组和信息源管理'**
  String get platformAdminSubtitle;

  /// No description provided for @userManagement.
  ///
  /// In zh, this message translates to:
  /// **'用户管理'**
  String get userManagement;

  /// No description provided for @userManagementSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理用户权限和会员等级'**
  String get userManagementSubtitle;

  /// No description provided for @aboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'应用信息、版本'**
  String get aboutSubtitle;

  /// No description provided for @articleDisplayMode.
  ///
  /// In zh, this message translates to:
  /// **'文章显示模式'**
  String get articleDisplayMode;

  /// No description provided for @listView.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get listView;

  /// No description provided for @listViewDesc.
  ///
  /// In zh, this message translates to:
  /// **'简单列表，显示标题和订阅源信息'**
  String get listViewDesc;

  /// No description provided for @magazineView.
  ///
  /// In zh, this message translates to:
  /// **'杂志'**
  String get magazineView;

  /// No description provided for @magazineViewDesc.
  ///
  /// In zh, this message translates to:
  /// **'丰富布局，包含内容预览'**
  String get magazineViewDesc;

  /// No description provided for @cardView.
  ///
  /// In zh, this message translates to:
  /// **'卡片'**
  String get cardView;

  /// No description provided for @cardViewDesc.
  ///
  /// In zh, this message translates to:
  /// **'基于图片的卡片布局'**
  String get cardViewDesc;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @followSystemDesc.
  ///
  /// In zh, this message translates to:
  /// **'Automatically switch based on system settings'**
  String get followSystemDesc;

  /// No description provided for @lightMode.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get lightMode;

  /// No description provided for @lightModeDesc.
  ///
  /// In zh, this message translates to:
  /// **'Use light theme'**
  String get lightModeDesc;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @darkModeDesc.
  ///
  /// In zh, this message translates to:
  /// **'Use dark theme'**
  String get darkModeDesc;

  /// No description provided for @amoledBlack.
  ///
  /// In zh, this message translates to:
  /// **'AMOLED纯黑模式'**
  String get amoledBlack;

  /// No description provided for @themeColor.
  ///
  /// In zh, this message translates to:
  /// **'主题颜色'**
  String get themeColor;

  /// No description provided for @colorSchemeStyleTitle.
  ///
  /// In zh, this message translates to:
  /// **'配色方案风格'**
  String get colorSchemeStyleTitle;

  /// No description provided for @tonalSpot.
  ///
  /// In zh, this message translates to:
  /// **'色调斑点'**
  String get tonalSpot;

  /// No description provided for @tonalSpotDesc.
  ///
  /// In zh, this message translates to:
  /// **'默认柔和调色板，低饱和度'**
  String get tonalSpotDesc;

  /// No description provided for @fidelity.
  ///
  /// In zh, this message translates to:
  /// **'保真度'**
  String get fidelity;

  /// No description provided for @fidelityDesc.
  ///
  /// In zh, this message translates to:
  /// **'匹配主题颜色，即使很亮'**
  String get fidelityDesc;

  /// No description provided for @neutral.
  ///
  /// In zh, this message translates to:
  /// **'中性'**
  String get neutral;

  /// No description provided for @neutralDesc.
  ///
  /// In zh, this message translates to:
  /// **'接近灰度，带一点色彩'**
  String get neutralDesc;

  /// No description provided for @gestureOperations.
  ///
  /// In zh, this message translates to:
  /// **'手势操作'**
  String get gestureOperations;

  /// No description provided for @hapticFeedback.
  ///
  /// In zh, this message translates to:
  /// **'触感反馈'**
  String get hapticFeedback;

  /// No description provided for @hapticFeedbackDesc.
  ///
  /// In zh, this message translates to:
  /// **'点击和滑动时提供震动反馈'**
  String get hapticFeedbackDesc;

  /// No description provided for @immersiveReading.
  ///
  /// In zh, this message translates to:
  /// **'自动沉浸式阅读'**
  String get immersiveReading;

  /// No description provided for @immersiveReadingDesc.
  ///
  /// In zh, this message translates to:
  /// **'阅读文章时自动隐藏顶部工具栏和底部操作栏'**
  String get immersiveReadingDesc;

  /// No description provided for @swipeToChange.
  ///
  /// In zh, this message translates to:
  /// **'文章滑动切换'**
  String get swipeToChange;

  /// No description provided for @swipeToChangeDesc.
  ///
  /// In zh, this message translates to:
  /// **'在文章详情页面左右滑动切换文章'**
  String get swipeToChangeDesc;

  /// No description provided for @scrollMarkRead.
  ///
  /// In zh, this message translates to:
  /// **'滚动自动标记已读'**
  String get scrollMarkRead;

  /// No description provided for @scrollMarkReadDesc.
  ///
  /// In zh, this message translates to:
  /// **'滚动时文章变得可见时自动将其标记为已读'**
  String get scrollMarkReadDesc;

  /// No description provided for @lazyLoadDetails.
  ///
  /// In zh, this message translates to:
  /// **'文章详情懒加载'**
  String get lazyLoadDetails;

  /// No description provided for @lazyLoadDetailsDesc.
  ///
  /// In zh, this message translates to:
  /// **'提升部分设备性能，但可能导致滚动条跳动'**
  String get lazyLoadDetailsDesc;

  /// No description provided for @useExternalBrowser.
  ///
  /// In zh, this message translates to:
  /// **'使用外部浏览器打开'**
  String get useExternalBrowser;

  /// No description provided for @useExternalBrowserDesc.
  ///
  /// In zh, this message translates to:
  /// **'在外部浏览器中打开文章链接，而不是应用内浏览器'**
  String get useExternalBrowserDesc;

  /// No description provided for @fabPosition.
  ///
  /// In zh, this message translates to:
  /// **'标记已读悬浮按钮位置'**
  String get fabPosition;

  /// No description provided for @fabPositionDesc.
  ///
  /// In zh, this message translates to:
  /// **'选择标记为已读悬浮按钮的位置'**
  String get fabPositionDesc;

  /// No description provided for @fabHidden.
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get fabHidden;

  /// No description provided for @pageSize.
  ///
  /// In zh, this message translates to:
  /// **'每页文章数量'**
  String get pageSize;

  /// No description provided for @pageSizeDesc.
  ///
  /// In zh, this message translates to:
  /// **'每次加载的文章数量。这也影响AI聚合读取时使用的文章数量。'**
  String get pageSizeDesc;

  /// No description provided for @startupPage.
  ///
  /// In zh, this message translates to:
  /// **'启动页'**
  String get startupPage;

  /// No description provided for @startupPageDesc.
  ///
  /// In zh, this message translates to:
  /// **'选择应用启动时显示的页面'**
  String get startupPageDesc;

  /// No description provided for @languageSettings.
  ///
  /// In zh, this message translates to:
  /// **'语言设置'**
  String get languageSettings;

  /// No description provided for @appLanguage.
  ///
  /// In zh, this message translates to:
  /// **'应用语言'**
  String get appLanguage;

  /// No description provided for @appLanguageDesc.
  ///
  /// In zh, this message translates to:
  /// **'应用界面使用的语言'**
  String get appLanguageDesc;

  /// No description provided for @followSystemLang.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystemLang;

  /// No description provided for @aiGeneratedLanguage.
  ///
  /// In zh, this message translates to:
  /// **'AI 生成语言'**
  String get aiGeneratedLanguage;

  /// No description provided for @aiGeneratedLanguageDesc.
  ///
  /// In zh, this message translates to:
  /// **'AI生成内容（摘要等）使用的语言'**
  String get aiGeneratedLanguageDesc;

  /// No description provided for @followAppLang.
  ///
  /// In zh, this message translates to:
  /// **'跟随应用语言'**
  String get followAppLang;

  /// No description provided for @translationLanguage.
  ///
  /// In zh, this message translates to:
  /// **'翻译语言'**
  String get translationLanguage;

  /// No description provided for @translationLanguageDesc.
  ///
  /// In zh, this message translates to:
  /// **'文章翻译的目标语言'**
  String get translationLanguageDesc;

  /// No description provided for @languageSupportNote.
  ///
  /// In zh, this message translates to:
  /// **'语言支持取决于大模型和翻译引擎的能力'**
  String get languageSupportNote;

  /// No description provided for @syncSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步设置'**
  String get syncSettingsTitle;

  /// No description provided for @localConnectionConfig.
  ///
  /// In zh, this message translates to:
  /// **'本地连接配置'**
  String get localConnectionConfig;

  /// No description provided for @backendApiUrl.
  ///
  /// In zh, this message translates to:
  /// **'后端 API Base URL'**
  String get backendApiUrl;

  /// No description provided for @apiUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'http://192.168.1.1:8080'**
  String get apiUrlHint;

  /// No description provided for @serverBackgroundConfig.
  ///
  /// In zh, this message translates to:
  /// **'服务器后台配置 (全局)'**
  String get serverBackgroundConfig;

  /// No description provided for @autoRefreshInterval.
  ///
  /// In zh, this message translates to:
  /// **'自动刷新间隔 (分钟)'**
  String get autoRefreshInterval;

  /// No description provided for @minutes.
  ///
  /// In zh, this message translates to:
  /// **' 分钟'**
  String get minutes;

  /// No description provided for @rsshubInstanceUrl.
  ///
  /// In zh, this message translates to:
  /// **'RSSHub 实例地址'**
  String get rsshubInstanceUrl;

  /// No description provided for @opmlImportExport.
  ///
  /// In zh, this message translates to:
  /// **'导入/导出'**
  String get opmlImportExport;

  /// No description provided for @opmlImport.
  ///
  /// In zh, this message translates to:
  /// **'OPML 导入'**
  String get opmlImport;

  /// No description provided for @opmlImportDesc.
  ///
  /// In zh, this message translates to:
  /// **'从其他 RSS 阅读器导入订阅源。支持 .opml 或 .xml 文件格式。'**
  String get opmlImportDesc;

  /// No description provided for @importing.
  ///
  /// In zh, this message translates to:
  /// **'导入中...'**
  String get importing;

  /// No description provided for @selectFileAndImport.
  ///
  /// In zh, this message translates to:
  /// **'选择文件并导入'**
  String get selectFileAndImport;

  /// No description provided for @opmlExport.
  ///
  /// In zh, this message translates to:
  /// **'OPML 导出'**
  String get opmlExport;

  /// No description provided for @opmlExportDesc.
  ///
  /// In zh, this message translates to:
  /// **'将当前的订阅源导出为 OPML 格式，以便在其他阅读器中使用。'**
  String get opmlExportDesc;

  /// No description provided for @exporting.
  ///
  /// In zh, this message translates to:
  /// **'导出中...'**
  String get exporting;

  /// No description provided for @exportAndShare.
  ///
  /// In zh, this message translates to:
  /// **'导出并分享'**
  String get exportAndShare;

  /// No description provided for @importResult.
  ///
  /// In zh, this message translates to:
  /// **'导入结果'**
  String get importResult;

  /// No description provided for @importResultDetail.
  ///
  /// In zh, this message translates to:
  /// **'成功导入: {imported}\n跳过: {skipped}\n错误: {errors}'**
  String importResultDetail(Object errors, Object imported, Object skipped);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get importFailed;

  /// No description provided for @exportShareTitle.
  ///
  /// In zh, this message translates to:
  /// **'TAN RSS 订阅源导出'**
  String get exportShareTitle;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get exportFailed;

  /// No description provided for @aiSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI功能'**
  String get aiSettingsTitle;

  /// No description provided for @aiProvider.
  ///
  /// In zh, this message translates to:
  /// **'AI提供商'**
  String get aiProvider;

  /// No description provided for @providerConfig.
  ///
  /// In zh, this message translates to:
  /// **'{provider} 配置'**
  String providerConfig(Object provider);

  /// No description provided for @apiKey.
  ///
  /// In zh, this message translates to:
  /// **'API密钥'**
  String get apiKey;

  /// No description provided for @apiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入 API 密钥'**
  String get apiKeyHint;

  /// No description provided for @baseUrlOptional.
  ///
  /// In zh, this message translates to:
  /// **'基础URL（可选）'**
  String get baseUrlOptional;

  /// No description provided for @modelOptional.
  ///
  /// In zh, this message translates to:
  /// **'模型（可选）'**
  String get modelOptional;

  /// No description provided for @getApiKey.
  ///
  /// In zh, this message translates to:
  /// **'获取 {provider} API密钥'**
  String getApiKey(Object provider);

  /// No description provided for @aiInstructionManagement.
  ///
  /// In zh, this message translates to:
  /// **'AI指令管理'**
  String get aiInstructionManagement;

  /// No description provided for @articleAggregationPrompts.
  ///
  /// In zh, this message translates to:
  /// **'文章聚合提示词'**
  String get articleAggregationPrompts;

  /// No description provided for @addCustomInstruction.
  ///
  /// In zh, this message translates to:
  /// **'添加自定义指令'**
  String get addCustomInstruction;

  /// No description provided for @editCustomInstruction.
  ///
  /// In zh, this message translates to:
  /// **'编辑自定义指令'**
  String get editCustomInstruction;

  /// No description provided for @promptName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get promptName;

  /// No description provided for @promptType.
  ///
  /// In zh, this message translates to:
  /// **'类型 (summary 或 synthesis)'**
  String get promptType;

  /// No description provided for @promptContent.
  ///
  /// In zh, this message translates to:
  /// **'指令内容'**
  String get promptContent;

  /// No description provided for @deletePromptConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get deletePromptConfirm;

  /// No description provided for @deletePromptContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个自定义指令吗？'**
  String get deletePromptContent;

  /// No description provided for @tips.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get tips;

  /// No description provided for @tip1.
  ///
  /// In zh, this message translates to:
  /// **'使用 {title} 和 {content} 占位符来引用文章信息'**
  String tip1(Object content, Object title);

  /// No description provided for @tip2.
  ///
  /// In zh, this message translates to:
  /// **'使用 {language} 占位符来引用AI生成语言'**
  String tip2(Object language);

  /// No description provided for @tip3.
  ///
  /// In zh, this message translates to:
  /// **'API密钥安全存储在您的本地设备上'**
  String get tip3;

  /// No description provided for @tip4.
  ///
  /// In zh, this message translates to:
  /// **'您可以配置自定义模型和端点以供高级使用'**
  String get tip4;

  /// No description provided for @advancedFeatures.
  ///
  /// In zh, this message translates to:
  /// **'高级功能开关'**
  String get advancedFeatures;

  /// No description provided for @autoQualityScoring.
  ///
  /// In zh, this message translates to:
  /// **'自动质量评分'**
  String get autoQualityScoring;

  /// No description provided for @autoQualityScoringDesc.
  ///
  /// In zh, this message translates to:
  /// **'使用 AI 评估文章质量并过滤低质内容'**
  String get autoQualityScoringDesc;

  /// No description provided for @autoSummary.
  ///
  /// In zh, this message translates to:
  /// **'自动生成摘要'**
  String get autoSummary;

  /// No description provided for @autoSummaryDesc.
  ///
  /// In zh, this message translates to:
  /// **'后台自动为新文章生成 AI 摘要'**
  String get autoSummaryDesc;

  /// No description provided for @autoTitleTranslation.
  ///
  /// In zh, this message translates to:
  /// **'自动翻译标题'**
  String get autoTitleTranslation;

  /// No description provided for @autoTitleTranslationDesc.
  ///
  /// In zh, this message translates to:
  /// **'自动翻译外文标题'**
  String get autoTitleTranslationDesc;

  /// No description provided for @autoContentTranslation.
  ///
  /// In zh, this message translates to:
  /// **'自动翻译全文'**
  String get autoContentTranslation;

  /// No description provided for @autoContentTranslationDesc.
  ///
  /// In zh, this message translates to:
  /// **'后台自动翻译未读文章'**
  String get autoContentTranslationDesc;

  /// No description provided for @saveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get saveSuccess;

  /// No description provided for @testing.
  ///
  /// In zh, this message translates to:
  /// **'正在测试...'**
  String get testing;

  /// No description provided for @testSuccess.
  ///
  /// In zh, this message translates to:
  /// **'测试成功！'**
  String get testSuccess;

  /// No description provided for @testFailed.
  ///
  /// In zh, this message translates to:
  /// **'测试失败，请检查配置。'**
  String get testFailed;

  /// No description provided for @upgrade.
  ///
  /// In zh, this message translates to:
  /// **'升级'**
  String get upgrade;

  /// No description provided for @freeMemberAiHint.
  ///
  /// In zh, this message translates to:
  /// **'Free 会员需要配置自己的 API 密钥才能使用 AI 功能。升级 Plus 享受免配置开箱即用的 AI 体验！'**
  String get freeMemberAiHint;

  /// No description provided for @plusMemberHint.
  ///
  /// In zh, this message translates to:
  /// **'您当前享有平台 AI 服务调用特权。今日已调用: {count} 次。'**
  String plusMemberHint(Object count);

  /// No description provided for @membershipTitle.
  ///
  /// In zh, this message translates to:
  /// **'会员中心'**
  String get membershipTitle;

  /// No description provided for @upgradeSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已成功升级至 {tier} 会员！'**
  String upgradeSuccess(Object tier);

  /// No description provided for @upgradeFailed.
  ///
  /// In zh, this message translates to:
  /// **'升级失败'**
  String get upgradeFailed;

  /// No description provided for @currentLevel.
  ///
  /// In zh, this message translates to:
  /// **'当前等级: {tier}'**
  String currentLevel(Object tier);

  /// No description provided for @expirationTime.
  ///
  /// In zh, this message translates to:
  /// **'到期时间: {time}'**
  String expirationTime(Object time);

  /// No description provided for @todayAiCalls.
  ///
  /// In zh, this message translates to:
  /// **'今日平台AI调用次数: {count} 次'**
  String todayAiCalls(Object count);

  /// No description provided for @subscriptionPlans.
  ///
  /// In zh, this message translates to:
  /// **'订阅计划'**
  String get subscriptionPlans;

  /// No description provided for @freePlan.
  ///
  /// In zh, this message translates to:
  /// **'Free 基础版'**
  String get freePlan;

  /// No description provided for @freePrice.
  ///
  /// In zh, this message translates to:
  /// **'免费'**
  String get freePrice;

  /// No description provided for @freeFeature1.
  ///
  /// In zh, this message translates to:
  /// **'基础 RSS 订阅管理'**
  String get freeFeature1;

  /// No description provided for @freeFeature2.
  ///
  /// In zh, this message translates to:
  /// **'支持自定义接入 AI 模型 (自带 Key)'**
  String get freeFeature2;

  /// No description provided for @freeFeature3.
  ///
  /// In zh, this message translates to:
  /// **'社区插件与精选包'**
  String get freeFeature3;

  /// No description provided for @currentPlan.
  ///
  /// In zh, this message translates to:
  /// **'当前计划'**
  String get currentPlan;

  /// No description provided for @downgrade.
  ///
  /// In zh, this message translates to:
  /// **'降级'**
  String get downgrade;

  /// No description provided for @plusPlan.
  ///
  /// In zh, this message translates to:
  /// **'Plus 专业版'**
  String get plusPlan;

  /// No description provided for @plusPrice.
  ///
  /// In zh, this message translates to:
  /// **'￥15 / 月'**
  String get plusPrice;

  /// No description provided for @plusFeature1.
  ///
  /// In zh, this message translates to:
  /// **'包含所有 Free 版功能'**
  String get plusFeature1;

  /// No description provided for @plusFeature2.
  ///
  /// In zh, this message translates to:
  /// **'免配置直接使用平台高质量 AI 模型'**
  String get plusFeature2;

  /// No description provided for @plusFeature3.
  ///
  /// In zh, this message translates to:
  /// **'每日 50 次平台 AI 调用额度'**
  String get plusFeature3;

  /// No description provided for @plusFeature4.
  ///
  /// In zh, this message translates to:
  /// **'支持自定义 AI 指令管理'**
  String get plusFeature4;

  /// No description provided for @upgradeNow.
  ///
  /// In zh, this message translates to:
  /// **'立即升级'**
  String get upgradeNow;

  /// No description provided for @proPlan.
  ///
  /// In zh, this message translates to:
  /// **'Pro 终极版'**
  String get proPlan;

  /// No description provided for @proPrice.
  ///
  /// In zh, this message translates to:
  /// **'￥45 / 月'**
  String get proPrice;

  /// No description provided for @proFeature1.
  ///
  /// In zh, this message translates to:
  /// **'包含所有 Plus 版功能'**
  String get proFeature1;

  /// No description provided for @proFeature2.
  ///
  /// In zh, this message translates to:
  /// **'每日 500 次平台高级 AI 调用额度'**
  String get proFeature2;

  /// No description provided for @proFeature3.
  ///
  /// In zh, this message translates to:
  /// **'高级主题定制 (即将推出)'**
  String get proFeature3;

  /// No description provided for @proFeature4.
  ///
  /// In zh, this message translates to:
  /// **'优先客服支持'**
  String get proFeature4;

  /// No description provided for @currentBadge.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get currentBadge;

  /// No description provided for @accountManagement.
  ///
  /// In zh, this message translates to:
  /// **'账户管理'**
  String get accountManagement;

  /// No description provided for @roleAdmin.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get roleAdmin;

  /// No description provided for @roleUser.
  ///
  /// In zh, this message translates to:
  /// **'普通用户'**
  String get roleUser;

  /// No description provided for @email.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get email;

  /// No description provided for @emailNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get emailNotSet;

  /// No description provided for @registrationTime.
  ///
  /// In zh, this message translates to:
  /// **'注册时间'**
  String get registrationTime;

  /// No description provided for @accountStatus.
  ///
  /// In zh, this message translates to:
  /// **'账户状态'**
  String get accountStatus;

  /// No description provided for @statusActive.
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get statusActive;

  /// No description provided for @statusDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已禁用'**
  String get statusDisabled;

  /// No description provided for @accountOperations.
  ///
  /// In zh, this message translates to:
  /// **'账户操作'**
  String get accountOperations;

  /// No description provided for @changeEmail.
  ///
  /// In zh, this message translates to:
  /// **'修改邮箱'**
  String get changeEmail;

  /// No description provided for @newEmailLabel.
  ///
  /// In zh, this message translates to:
  /// **'新邮箱地址'**
  String get newEmailLabel;

  /// No description provided for @newEmailHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入新的邮箱地址'**
  String get newEmailHint;

  /// No description provided for @emailEmpty.
  ///
  /// In zh, this message translates to:
  /// **'邮箱不能为空'**
  String get emailEmpty;

  /// No description provided for @emailUpdateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'邮箱修改成功'**
  String get emailUpdateSuccess;

  /// No description provided for @changePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In zh, this message translates to:
  /// **'当前密码'**
  String get currentPassword;

  /// No description provided for @currentPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前密码'**
  String get currentPasswordHint;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPassword;

  /// No description provided for @newPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'至少 6 个字符'**
  String get newPasswordHint;

  /// No description provided for @confirmNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get confirmNewPassword;

  /// No description provided for @confirmNewPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'再次输入新密码'**
  String get confirmNewPasswordHint;

  /// No description provided for @fillAllPasswordFields.
  ///
  /// In zh, this message translates to:
  /// **'请填写所有密码字段'**
  String get fillAllPasswordFields;

  /// No description provided for @newPasswordMinChars.
  ///
  /// In zh, this message translates to:
  /// **'新密码至少需要 6 个字符'**
  String get newPasswordMinChars;

  /// No description provided for @passwordsMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的新密码不一致'**
  String get passwordsMismatch;

  /// No description provided for @passwordUpdateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密码修改成功'**
  String get passwordUpdateSuccess;

  /// No description provided for @logoutConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get logoutConfirm;

  /// No description provided for @logoutConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出登录吗？'**
  String get logoutConfirmContent;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get logout;

  /// No description provided for @logoutButton.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logoutButton;

  /// No description provided for @changeEmailAction.
  ///
  /// In zh, this message translates to:
  /// **'修改邮箱'**
  String get changeEmailAction;

  /// No description provided for @changePasswordAction.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePasswordAction;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'定期更换密码可提高账户安全'**
  String get changePasswordSubtitle;

  /// No description provided for @dailyDigestTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 每日简报'**
  String get dailyDigestTitle;

  /// No description provided for @regenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get regenerate;

  /// No description provided for @readingAllUnread.
  ///
  /// In zh, this message translates to:
  /// **'正在阅读所有未读文章...\nAI 编辑部正在为您撰写今日简报'**
  String get readingAllUnread;

  /// No description provided for @generationFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败'**
  String get generationFailed;

  /// No description provided for @noArticlesForDigest.
  ///
  /// In zh, this message translates to:
  /// **'暂无最新文章可供生成简报'**
  String get noArticlesForDigest;

  /// No description provided for @referenceSource.
  ///
  /// In zh, this message translates to:
  /// **'来源 [{index}]'**
  String referenceSource(Object index);

  /// No description provided for @readOriginal.
  ///
  /// In zh, this message translates to:
  /// **'阅读原文'**
  String get readOriginal;

  /// No description provided for @aiSynthesis.
  ///
  /// In zh, this message translates to:
  /// **'AI 聚合'**
  String get aiSynthesis;

  /// No description provided for @ttsComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将推出 TTS 朗读功能'**
  String get ttsComingSoon;

  /// No description provided for @readingChannelArticles.
  ///
  /// In zh, this message translates to:
  /// **'正在阅读 {channelName} 近期文章...\nAI 正在为您生成聚合分析报告'**
  String readingChannelArticles(Object channelName);

  /// No description provided for @synthesisFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败'**
  String get synthesisFailed;

  /// No description provided for @noArticlesToAnalyze.
  ///
  /// In zh, this message translates to:
  /// **'没有可分析的文章'**
  String get noArticlesToAnalyze;

  /// No description provided for @reference.
  ///
  /// In zh, this message translates to:
  /// **'引用 [{index}]'**
  String reference(Object index);

  /// No description provided for @userManagementTitle.
  ///
  /// In zh, this message translates to:
  /// **'用户管理'**
  String get userManagementTitle;

  /// No description provided for @noUsers.
  ///
  /// In zh, this message translates to:
  /// **'暂无用户'**
  String get noUsers;

  /// No description provided for @editUser.
  ///
  /// In zh, this message translates to:
  /// **'编辑用户'**
  String get editUser;

  /// No description provided for @role.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get role;

  /// No description provided for @membershipTier.
  ///
  /// In zh, this message translates to:
  /// **'会员等级'**
  String get membershipTier;

  /// No description provided for @isActive.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get isActive;

  /// No description provided for @active.
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get active;

  /// No description provided for @disabled.
  ///
  /// In zh, this message translates to:
  /// **'已禁用'**
  String get disabled;

  /// No description provided for @userUpdated.
  ///
  /// In zh, this message translates to:
  /// **'用户更新成功'**
  String get userUpdated;

  /// No description provided for @updateUserFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新用户失败'**
  String get updateUserFailed;

  /// No description provided for @deleteUser.
  ///
  /// In zh, this message translates to:
  /// **'删除用户'**
  String get deleteUser;

  /// No description provided for @deleteUserConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除用户 \"{name}\" 吗？'**
  String deleteUserConfirm(Object name);

  /// No description provided for @userDeleted.
  ///
  /// In zh, this message translates to:
  /// **'用户已删除'**
  String get userDeleted;

  /// No description provided for @deleteUserFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除用户失败'**
  String get deleteUserFailed;

  /// No description provided for @healthCheck.
  ///
  /// In zh, this message translates to:
  /// **'服务器状态检测'**
  String get healthCheck;

  /// No description provided for @serverOnline.
  ///
  /// In zh, this message translates to:
  /// **'服务器连接正常'**
  String get serverOnline;

  /// No description provided for @serverOffline.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到服务器'**
  String get serverOffline;

  /// No description provided for @checkNow.
  ///
  /// In zh, this message translates to:
  /// **'立即检测'**
  String get checkNow;

  /// No description provided for @dateFormatYear.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get dateFormatYear;

  /// No description provided for @dateFormatMonth.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get dateFormatMonth;

  /// No description provided for @dateFormatDay.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get dateFormatDay;

  /// No description provided for @readCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 篇文章'**
  String readCount(Object count);

  /// No description provided for @defaultValue.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get defaultValue;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
