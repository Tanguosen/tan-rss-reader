// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'TAN RSS';

  @override
  String get appTitleFull => 'TAN RSS Reader';

  @override
  String get navArticles => '文章';

  @override
  String get navChannels => '频道';

  @override
  String get navDiscovery => '发现';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get add => '添加';

  @override
  String get create => '创建';

  @override
  String get retry => '重试';

  @override
  String get refresh => '刷新';

  @override
  String get back => '返回';

  @override
  String get done => '完成';

  @override
  String get remove => '移除';

  @override
  String get subscribe => '订阅';

  @override
  String get unsubscribe => '取消订阅';

  @override
  String get loadFailed => '加载失败';

  @override
  String get operationFailed => '操作失败';

  @override
  String get createFailed => '创建失败';

  @override
  String get updateFailed => '更新失败';

  @override
  String get deleteFailed => '删除失败';

  @override
  String get saveFailed => '保存失败';

  @override
  String get search => '搜索';

  @override
  String get all => '全部';

  @override
  String get noTitle => '无标题';

  @override
  String get noContent => '暂无内容';

  @override
  String get noDescription => '暂无描述';

  @override
  String get comingSoon => '即将推出';

  @override
  String get unknown => '未知';

  @override
  String get settings => '设置';

  @override
  String get about => '关于';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutDescription => '一个现代化的AI-RSS阅读器，支持AI摘要、智能翻译和优雅的阅读体验。';

  @override
  String get aboutSlogan => 'TAN 致力于为你的信息流带来清爽高效的阅读体验。';

  @override
  String get aboutCoreFeatures => '核心特性';

  @override
  String get aboutCoreFeaturesDesc => 'RSS订阅 · AI摘要 · 智能翻译 · 收藏管理';

  @override
  String get aboutTechStack => '技术架构';

  @override
  String get aboutTechStackDesc =>
      'Flutter 前端 | Python FastAPI 后端 | SQLite 数据库';

  @override
  String get login => '登录';

  @override
  String get register => '注册';

  @override
  String get username => '用户名';

  @override
  String get usernameHint => '请输入用户名';

  @override
  String get usernameHelper => '仅允许字母、数字、下划线(_)和连字符(-)，至少 3 个字符';

  @override
  String get password => '密码';

  @override
  String get passwordHint => '请输入密码';

  @override
  String get passwordHelper => '至少 6 个字符';

  @override
  String get emailOptional => '邮箱（可选）';

  @override
  String get emailHint => '请输入邮箱地址';

  @override
  String get loginWelcome => '欢迎回来，请登录';

  @override
  String get createNewAccount => '创建新账号';

  @override
  String get noAccount => '没有账号？ ';

  @override
  String get clickToRegister => '点击注册';

  @override
  String get hasAccount => '已有账号？ ';

  @override
  String get clickToLogin => '点击登录';

  @override
  String get loginSuccess => '登录成功';

  @override
  String get loginSuccessWelcome => '登录成功，欢迎回来！';

  @override
  String get registerSuccess => '注册成功，欢迎加入！';

  @override
  String get usernameRequired => '请输入用户名';

  @override
  String get usernameMinChars => '用户名至少需要 3 个字符';

  @override
  String get usernameInvalidChars => '用户名只能包含字母、数字、_ 和 -';

  @override
  String get emailFormatInvalid => '邮箱格式不正确';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get passwordMinChars => '密码至少需要 6 个字符';

  @override
  String get passwordLengthError => '密码长度不能少于 6 位';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get serverAddressHint => '请输入服务器地址';

  @override
  String get serverAddressMustHttp => '地址必须以 http 或 https 开头';

  @override
  String get collapseConfig => '收起配置';

  @override
  String get serverConfig => '服务器配置';

  @override
  String get myChannels => '我的频道';

  @override
  String get noSubscribedChannels => '暂无订阅的频道';

  @override
  String get goToChannelSquare => '去频道广场逛逛';

  @override
  String get starred => '收藏';

  @override
  String get noStarredArticles => '还没有收藏的文章';

  @override
  String get renameChannel => '重命名频道';

  @override
  String get newName => '新名称';

  @override
  String get deleteChannel => '删除频道';

  @override
  String get deleteChannelConfirm => '确定删除该频道？只移除频道与订阅关系，不会删除订阅源。';

  @override
  String get addFeedToChannel => '添加订阅到频道';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get titleOptional => '标题（可选）';

  @override
  String get createNewFeed => '新增订阅源';

  @override
  String get url => 'URL';

  @override
  String get editFeed => '编辑订阅源';

  @override
  String get title => '标题';

  @override
  String get updateIntervalMinutes => '更新间隔（分钟）';

  @override
  String get defaultInterval => '默认（15分钟）';

  @override
  String get minutes5 => '5分钟';

  @override
  String get minutes10 => '10分钟';

  @override
  String get minutes15 => '15分钟';

  @override
  String get minutes30 => '30分钟';

  @override
  String get hour1 => '1小时';

  @override
  String get hours2 => '2小时';

  @override
  String get hours6 => '6小时';

  @override
  String get hours12 => '12小时';

  @override
  String get hours24 => '24小时';

  @override
  String unsubscribeConfirm(Object title) {
    return '确定取消订阅「$title」？\n取消后将不再收到该订阅源的更新。';
  }

  @override
  String get thinkAgain => '再想想';

  @override
  String get confirmUnsubscribe => '确定取消';

  @override
  String get unsubscribed => '已取消订阅';

  @override
  String get allUnread => '所有未读';

  @override
  String unreadCount(Object count) {
    return '$count 未读';
  }

  @override
  String get addFeedHere => '在此频道添加订阅';

  @override
  String get renameChannelMenu => '重命名频道';

  @override
  String get deleteChannelMenu => '删除频道';

  @override
  String get noFeedsClickToAdd => '暂无订阅源，点击右上角 + 添加';

  @override
  String get addSubscriptionSource => '添加订阅源';

  @override
  String get subscriptionLink => '订阅链接';

  @override
  String get subscriptionLinkHint => 'https://example.com/feed.xml';

  @override
  String get paste => '粘贴';

  @override
  String get enterSubscriptionLink => '请输入订阅链接';

  @override
  String get linkMustHttp => '链接必须以 http:// 或 https:// 开头';

  @override
  String get addingContent => '正在添加并获取内容...';

  @override
  String get addSubscriptionSourceButton => '添加订阅源';

  @override
  String get supportedSources => '支持的内容来源';

  @override
  String get blogWebsite => '博客 / 网站';

  @override
  String get other => '其他';

  @override
  String get quickAddExamples => '快速添加示例';

  @override
  String get subscriptionAddedSuccess => '订阅源添加成功';

  @override
  String get fetchingInBackground => '正在后台获取最新内容...';

  @override
  String get reading => '阅读';

  @override
  String get aiSummary => 'AI 摘要';

  @override
  String get translateTitleButton => '翻译标题';

  @override
  String get translateContent => '翻译正文';

  @override
  String get deepDive => '深度解读';

  @override
  String get showTranslatedTitle => '显示翻译标题';

  @override
  String get showTranslatedContent => '显示翻译正文';

  @override
  String get aiDeepDive => 'AI 深度解读';

  @override
  String get aiSummaryFailed => 'AI 摘要失败：';

  @override
  String get titleTranslationFailed => '标题翻译失败：';

  @override
  String get contentTranslationFailed => '正文翻译失败：';

  @override
  String get deepDiveFailed => 'AI 深度解读失败：';

  @override
  String get markRead => '标记已读';

  @override
  String get markUnread => '标记未读';

  @override
  String get star => '收藏';

  @override
  String get unstar => '取消收藏';

  @override
  String get addToBatch => '加入批量';

  @override
  String get translateTitle => '翻译标题';

  @override
  String get articlesSection => '文章';

  @override
  String get batchOperation => '批量操作';

  @override
  String get unread => '未读';

  @override
  String get highQuality => '精选';

  @override
  String get starredFilter => '收藏';

  @override
  String selectedCount(Object count) {
    return '已选 $count 项';
  }

  @override
  String get batchStar => '批量收藏';

  @override
  String get batchUnstar => '批量取消';

  @override
  String get deselect => '取消选择';

  @override
  String get noArticlesMatch => '当前条件下没有文章';

  @override
  String get aiBriefing => 'AI 简报';

  @override
  String get noArticlesForBriefing => '当前没有文章可供生成简报';

  @override
  String get trendsTab => '话题趋势';

  @override
  String get semanticSearchTab => '语义搜索';

  @override
  String get majorEvents => '重大事件';

  @override
  String get sourceHighlights => '信息源高光';

  @override
  String get deepAnalysis => '深度解读';

  @override
  String get integratedToDailyBriefing => '已集成至每日简报';

  @override
  String get aiDailyBriefing => 'AI 每日简报';

  @override
  String get dailyBriefingDesc => '阅读所有频道的精华总结';

  @override
  String get noUnreadForBriefing => '当前没有未读文章可供生成简报';

  @override
  String get getArticlesFailed => '获取文章失败';

  @override
  String get timeRange => '时间范围: ';

  @override
  String get last24Hours => '最近 24 小时';

  @override
  String get last3Days => '最近 3 天';

  @override
  String get lastWeek => '最近一周';

  @override
  String get last1Month => '最近 1 个月';

  @override
  String get last3Months => '最近 3 个月';

  @override
  String get noTrendTopics => '该时间段内未发现趋势话题';

  @override
  String articleCount(Object count) {
    return '$count 篇';
  }

  @override
  String moreArticles(Object count) {
    return '+ $count 篇更多';
  }

  @override
  String get smartAnalysis => '智能分析';

  @override
  String get searchHint => '输入问题或描述...';

  @override
  String get searchFailed => '搜索失败';

  @override
  String get noResults => '未找到相关结果';

  @override
  String get inputKeywordsToSearch => '输入关键词开始搜索';

  @override
  String get publishTime => '发布时间: ';

  @override
  String get openArticleFailed => '打开文章失败';

  @override
  String get generatingAnalysis => '正在生成智能分析报告...';

  @override
  String get analysisFailed => '分析失败';

  @override
  String get noAnalysisData => '暂无分析数据';

  @override
  String get smartTrendAnalysis => '智能趋势分析';

  @override
  String get trendPrediction => '趋势预测';

  @override
  String get keywords => '关键词:';

  @override
  String get sentiment => '情感倾向:';

  @override
  String get sentimentPositive => '正面';

  @override
  String get sentimentNegative => '负面';

  @override
  String get sentimentNeutral => '中性';

  @override
  String get summary => '摘要';

  @override
  String get eventTimeline => '事件脉络';

  @override
  String get channelSquare => '频道广场';

  @override
  String get searchChannels => '搜索频道';

  @override
  String get discover => '发现';

  @override
  String get mySubscriptions => '我的订阅';

  @override
  String get curatedPacks => '精选包';

  @override
  String get noChannelsFound => '暂无频道';

  @override
  String get noSubscriptions => '暂无订阅';

  @override
  String get subscribed => '已订阅';

  @override
  String subscribedSuccess(Object name) {
    return '已订阅 $name';
  }

  @override
  String get subscribeFailed => '订阅失败';

  @override
  String get unsubscribeChannel => '取消订阅';

  @override
  String unsubscribeChannelConfirm(Object name) {
    return '确定取消订阅 \"$name\" 吗？';
  }

  @override
  String unsubscribedSuccess(Object name) {
    return '已取消订阅 $name';
  }

  @override
  String get unsubscribeFailed => '取消订阅失败';

  @override
  String get noPacks => '暂无精选包';

  @override
  String get clickToCreatePack => '点击右下角创建属于你的频道合集';

  @override
  String get oneClickSubscribe => '一键订阅';

  @override
  String channelCount(Object count) {
    return '$count 个频道';
  }

  @override
  String installCount(Object count) {
    return '$count 次安装';
  }

  @override
  String get includedChannels => '包含频道:';

  @override
  String moreChannels(Object count) {
    return '等 $count 个频道';
  }

  @override
  String installedPack(Object added, Object name) {
    return '已安装 \"$name\"，新增 $added 个频道订阅';
  }

  @override
  String skippedChannels(Object skipped) {
    return '，跳过 $skipped 个已订阅';
  }

  @override
  String get installFailed => '安装失败';

  @override
  String get createPack => '创建精选包';

  @override
  String get packNameRequired => '精选包名称 *';

  @override
  String get packNameHint => '例如：AI 资讯合集';

  @override
  String get packDesc => '描述（可选）';

  @override
  String get includedChannelsSection => '包含的频道';

  @override
  String get addChannels => '添加';

  @override
  String get noChannelsSelected => '暂未选择任何频道';

  @override
  String get selectChannels => '选择要加入的频道';

  @override
  String get noSubscribedChannelsForPack => '暂无订阅的频道，请先去订阅一些吧';

  @override
  String get packNameRequiredMsg => '请输入包名称';

  @override
  String get selectAtLeastOneChannel => '请至少选择一个频道';

  @override
  String get createSuccess => '创建成功';

  @override
  String get noArticlesForAnalysis => '暂无文章可供分析';

  @override
  String get channelLinkCopied => '频道链接已复制';

  @override
  String get getLatestContent => '获取最新内容';

  @override
  String get markAllAsRead => '全部设为已读';

  @override
  String get viewSources => '查看信息源';

  @override
  String get shareChannel => '分享频道';

  @override
  String get noArticles => '暂无文章';

  @override
  String newContentCount(Object count) {
    return '获取到 $count 条新内容';
  }

  @override
  String get alreadyLatest => '已是最新内容';

  @override
  String get refreshFailed => '刷新失败';

  @override
  String markedReadCount(Object count) {
    return '已将 $count 篇文章设为已读';
  }

  @override
  String get noUnreadArticles => '没有未读文章';

  @override
  String submittedBy(Object author) {
    return 'submitted by $author';
  }

  @override
  String get getLatestContentButton => '获取最新内容';

  @override
  String get channelManagement => '频道管理';

  @override
  String get noChannels => '暂无频道';

  @override
  String get clickPlusToCreateChannel => '点击右下角 + 创建新频道';

  @override
  String get createChannel => '创建频道';

  @override
  String get channelName => '频道名称';

  @override
  String get descriptionOptional => '描述（可选）';

  @override
  String get channelCreated => '频道创建成功';

  @override
  String get editChannel => '编辑频道';

  @override
  String get iconUrlOptional => '图标URL（可选）';

  @override
  String get coverUrlOptional => '封面URL（可选）';

  @override
  String get categoryOptional => '分类（可选）';

  @override
  String get noCategory => '无分类';

  @override
  String get publicChannel => '公开频道';

  @override
  String get publicChannelVisible => '所有用户可见';

  @override
  String get privateChannelVisible => '仅自己可见';

  @override
  String get channelUpdated => '频道更新成功';

  @override
  String deleteChannelConfirmAdmin(Object name) {
    return '确定删除频道 \"$name\" 吗？';
  }

  @override
  String get channelDeleted => '频道已删除';

  @override
  String get manageSources => '管理订阅源';

  @override
  String channelSources(Object channelName) {
    return '$channelName - 订阅源';
  }

  @override
  String get noSources => '暂无订阅源';

  @override
  String get clickPlusToAddSource => '点击右下角 + 添加订阅源';

  @override
  String get noUserFeeds => '您还没有订阅任何订阅源';

  @override
  String get allFeedsAdded => '所有订阅源已添加到此频道';

  @override
  String get addSource => '添加订阅源';

  @override
  String get sourceAdded => '订阅源已添加';

  @override
  String get addFailed => '添加失败';

  @override
  String get removeSource => '移除订阅源';

  @override
  String removeSourceConfirm(Object name) {
    return '确定从频道中移除 \"$name\" 吗？';
  }

  @override
  String get sourceRemoved => '订阅源已移除';

  @override
  String get removeFailed => '移除失败';

  @override
  String get platformAdmin => '平台管理中心';

  @override
  String get myChannelsAdmin => '我的频道';

  @override
  String get channelsTab => '频道';

  @override
  String get feedsTab => '订阅源';

  @override
  String get noChannelAdmin => '暂无频道';

  @override
  String get clickToCreateFirstChannel => '点击下方按钮创建第一个频道';

  @override
  String get noPersonalChannels => '暂无个人频道';

  @override
  String get platformChannels => '平台频道';

  @override
  String get personalChannels => '个人频道';

  @override
  String get createChannelAdmin => '创建频道';

  @override
  String get publicChannelOtherUsers => '其他用户可发现并订阅';

  @override
  String get privateChannelSelf => '仅自己可见';

  @override
  String get deleteChannelAdmin => '删除频道';

  @override
  String deleteChannelAdminConfirm(Object name) {
    return '确定要删除 \"$name\" 吗？这不会删除其包含的信息源。';
  }

  @override
  String get channelDeletedAdmin => '频道已删除';

  @override
  String get noSourcesAdmin => '暂无订阅源，点击 + 添加';

  @override
  String sourcesCount(Object count) {
    return '$count 个订阅源';
  }

  @override
  String get addSourceAdmin => '添加订阅源';

  @override
  String get sourceAddedAdmin => '订阅源添加成功';

  @override
  String get addFailedAdmin => '添加失败';

  @override
  String get removeSourceAdmin => '移除订阅源';

  @override
  String removeSourceAdminConfirm(Object name) {
    return '确定要移除「$name」吗？';
  }

  @override
  String get removeFailedAdmin => '移除失败';

  @override
  String get noFeedsAdmin => '暂无订阅源';

  @override
  String get addFeedAdmin => '添加订阅源';

  @override
  String get deleteFeed => '删除订阅源';

  @override
  String deleteFeedConfirm(Object title) {
    return '确定要删除订阅源「$title」吗？';
  }

  @override
  String get feedDeleted => '已删除';

  @override
  String get deleteFeedFailed => '删除失败';

  @override
  String get addButton => '添加订阅源';

  @override
  String get changelog => '更新日志';

  @override
  String get changelogSubtitle => '查看最新版本的改进内容';

  @override
  String get membershipCenter => '会员中心';

  @override
  String get membershipSubtitle => '解锁高级 AI 功能与特权';

  @override
  String get account => '账户';

  @override
  String get accountSubtitle => '本地, 云端同步';

  @override
  String get colorAndStyle => '颜色和样式';

  @override
  String get colorAndStyleSubtitle => '主题, 文章样式';

  @override
  String get interaction => '交互';

  @override
  String get interactionSubtitle => '手势操作, 启动页面';

  @override
  String get language => '语言';

  @override
  String get languageSubtitle => '界面、AI、翻译';

  @override
  String get aiFeatures => 'AI功能';

  @override
  String get aiFeaturesSubtitle => 'AI 提供商, AI 指令';

  @override
  String get highlightSettings => '高亮设置';

  @override
  String get highlightSubtitle => '管理文章中的关键词高亮';

  @override
  String get ttsSettings => 'TTS设置';

  @override
  String get ttsSubtitle => '语音、语言设置';

  @override
  String get syncSettings => '同步设置';

  @override
  String get syncSubtitle => '自动刷新, API 地址配置';

  @override
  String get importExport => '导入/导出';

  @override
  String get importExportSubtitle => '订阅源, App 设置';

  @override
  String get platformAdminCenter => '平台管理中心';

  @override
  String get platformAdminSubtitle => '全局频道、分组和信息源管理';

  @override
  String get userManagement => '用户管理';

  @override
  String get userManagementSubtitle => '管理用户权限和会员等级';

  @override
  String get aboutSubtitle => '应用信息、版本';

  @override
  String get articleDisplayMode => '文章显示模式';

  @override
  String get listView => '列表';

  @override
  String get listViewDesc => '简单列表，显示标题和订阅源信息';

  @override
  String get magazineView => '杂志';

  @override
  String get magazineViewDesc => '丰富布局，包含内容预览';

  @override
  String get cardView => '卡片';

  @override
  String get cardViewDesc => '基于图片的卡片布局';

  @override
  String get themeMode => '主题模式';

  @override
  String get followSystem => '跟随系统';

  @override
  String get followSystemDesc =>
      'Automatically switch based on system settings';

  @override
  String get lightMode => '浅色模式';

  @override
  String get lightModeDesc => 'Use light theme';

  @override
  String get darkMode => '深色模式';

  @override
  String get darkModeDesc => 'Use dark theme';

  @override
  String get amoledBlack => 'AMOLED纯黑模式';

  @override
  String get themeColor => '主题颜色';

  @override
  String get colorSchemeStyleTitle => '配色方案风格';

  @override
  String get tonalSpot => '色调斑点';

  @override
  String get tonalSpotDesc => '默认柔和调色板，低饱和度';

  @override
  String get fidelity => '保真度';

  @override
  String get fidelityDesc => '匹配主题颜色，即使很亮';

  @override
  String get neutral => '中性';

  @override
  String get neutralDesc => '接近灰度，带一点色彩';

  @override
  String get gestureOperations => '手势操作';

  @override
  String get hapticFeedback => '触感反馈';

  @override
  String get hapticFeedbackDesc => '点击和滑动时提供震动反馈';

  @override
  String get immersiveReading => '自动沉浸式阅读';

  @override
  String get immersiveReadingDesc => '阅读文章时自动隐藏顶部工具栏和底部操作栏';

  @override
  String get swipeToChange => '文章滑动切换';

  @override
  String get swipeToChangeDesc => '在文章详情页面左右滑动切换文章';

  @override
  String get scrollMarkRead => '滚动自动标记已读';

  @override
  String get scrollMarkReadDesc => '滚动时文章变得可见时自动将其标记为已读';

  @override
  String get lazyLoadDetails => '文章详情懒加载';

  @override
  String get lazyLoadDetailsDesc => '提升部分设备性能，但可能导致滚动条跳动';

  @override
  String get useExternalBrowser => '使用外部浏览器打开';

  @override
  String get useExternalBrowserDesc => '在外部浏览器中打开文章链接，而不是应用内浏览器';

  @override
  String get fabPosition => '标记已读悬浮按钮位置';

  @override
  String get fabPositionDesc => '选择标记为已读悬浮按钮的位置';

  @override
  String get fabHidden => '隐藏';

  @override
  String get pageSize => '每页文章数量';

  @override
  String get pageSizeDesc => '每次加载的文章数量。这也影响AI聚合读取时使用的文章数量。';

  @override
  String get startupPage => '启动页';

  @override
  String get startupPageDesc => '选择应用启动时显示的页面';

  @override
  String get languageSettings => '语言设置';

  @override
  String get appLanguage => '应用语言';

  @override
  String get appLanguageDesc => '应用界面使用的语言';

  @override
  String get followSystemLang => '跟随系统';

  @override
  String get aiGeneratedLanguage => 'AI 生成语言';

  @override
  String get aiGeneratedLanguageDesc => 'AI生成内容（摘要等）使用的语言';

  @override
  String get followAppLang => '跟随应用语言';

  @override
  String get translationLanguage => '翻译语言';

  @override
  String get translationLanguageDesc => '文章翻译的目标语言';

  @override
  String get languageSupportNote => '语言支持取决于大模型和翻译引擎的能力';

  @override
  String get syncSettingsTitle => '同步设置';

  @override
  String get localConnectionConfig => '本地连接配置';

  @override
  String get backendApiUrl => '后端 API Base URL';

  @override
  String get apiUrlHint => 'http://192.168.1.1:8080';

  @override
  String get serverBackgroundConfig => '服务器后台配置 (全局)';

  @override
  String get autoRefreshInterval => '自动刷新间隔 (分钟)';

  @override
  String get minutes => ' 分钟';

  @override
  String get rsshubInstanceUrl => 'RSSHub 实例地址';

  @override
  String get opmlImportExport => '导入/导出';

  @override
  String get opmlImport => 'OPML 导入';

  @override
  String get opmlImportDesc => '从其他 RSS 阅读器导入订阅源。支持 .opml 或 .xml 文件格式。';

  @override
  String get importing => '导入中...';

  @override
  String get selectFileAndImport => '选择文件并导入';

  @override
  String get opmlExport => 'OPML 导出';

  @override
  String get opmlExportDesc => '将当前的订阅源导出为 OPML 格式，以便在其他阅读器中使用。';

  @override
  String get exporting => '导出中...';

  @override
  String get exportAndShare => '导出并分享';

  @override
  String get importResult => '导入结果';

  @override
  String importResultDetail(Object errors, Object imported, Object skipped) {
    return '成功导入: $imported\n跳过: $skipped\n错误: $errors';
  }

  @override
  String get importFailed => '导入失败';

  @override
  String get exportShareTitle => 'TAN RSS 订阅源导出';

  @override
  String get exportFailed => '导出失败';

  @override
  String get aiSettingsTitle => 'AI功能';

  @override
  String get aiProvider => 'AI提供商';

  @override
  String providerConfig(Object provider) {
    return '$provider 配置';
  }

  @override
  String get apiKey => 'API密钥';

  @override
  String get apiKeyHint => '请输入 API 密钥';

  @override
  String get baseUrlOptional => '基础URL（可选）';

  @override
  String get modelOptional => '模型（可选）';

  @override
  String getApiKey(Object provider) {
    return '获取 $provider API密钥';
  }

  @override
  String get aiInstructionManagement => 'AI指令管理';

  @override
  String get articleAggregationPrompts => '文章聚合提示词';

  @override
  String get addCustomInstruction => '添加自定义指令';

  @override
  String get editCustomInstruction => '编辑自定义指令';

  @override
  String get promptName => '名称';

  @override
  String get promptType => '类型 (summary 或 synthesis)';

  @override
  String get promptContent => '指令内容';

  @override
  String get deletePromptConfirm => '确认删除';

  @override
  String get deletePromptContent => '确定要删除这个自定义指令吗？';

  @override
  String get tips => '提示';

  @override
  String tip1(Object content, Object title) {
    return '使用 $title 和 $content 占位符来引用文章信息';
  }

  @override
  String tip2(Object language) {
    return '使用 $language 占位符来引用AI生成语言';
  }

  @override
  String get tip3 => 'API密钥安全存储在您的本地设备上';

  @override
  String get tip4 => '您可以配置自定义模型和端点以供高级使用';

  @override
  String get advancedFeatures => '高级功能开关';

  @override
  String get autoQualityScoring => '自动质量评分';

  @override
  String get autoQualityScoringDesc => '使用 AI 评估文章质量并过滤低质内容';

  @override
  String get autoSummary => '自动生成摘要';

  @override
  String get autoSummaryDesc => '后台自动为新文章生成 AI 摘要';

  @override
  String get autoTitleTranslation => '自动翻译标题';

  @override
  String get autoTitleTranslationDesc => '自动翻译外文标题';

  @override
  String get autoContentTranslation => '自动翻译全文';

  @override
  String get autoContentTranslationDesc => '后台自动翻译未读文章';

  @override
  String get saveSuccess => '保存成功';

  @override
  String get testing => '正在测试...';

  @override
  String get testSuccess => '测试成功！';

  @override
  String get testFailed => '测试失败，请检查配置。';

  @override
  String get upgrade => '升级';

  @override
  String get freeMemberAiHint =>
      'Free 会员需要配置自己的 API 密钥才能使用 AI 功能。升级 Plus 享受免配置开箱即用的 AI 体验！';

  @override
  String plusMemberHint(Object count) {
    return '您当前享有平台 AI 服务调用特权。今日已调用: $count 次。';
  }

  @override
  String get membershipTitle => '会员中心';

  @override
  String upgradeSuccess(Object tier) {
    return '已成功升级至 $tier 会员！';
  }

  @override
  String get upgradeFailed => '升级失败';

  @override
  String currentLevel(Object tier) {
    return '当前等级: $tier';
  }

  @override
  String expirationTime(Object time) {
    return '到期时间: $time';
  }

  @override
  String todayAiCalls(Object count) {
    return '今日平台AI调用次数: $count 次';
  }

  @override
  String get subscriptionPlans => '订阅计划';

  @override
  String get freePlan => 'Free 基础版';

  @override
  String get freePrice => '免费';

  @override
  String get freeFeature1 => '基础 RSS 订阅管理';

  @override
  String get freeFeature2 => '支持自定义接入 AI 模型 (自带 Key)';

  @override
  String get freeFeature3 => '社区插件与精选包';

  @override
  String get currentPlan => '当前计划';

  @override
  String get downgrade => '降级';

  @override
  String get plusPlan => 'Plus 专业版';

  @override
  String get plusPrice => '￥15 / 月';

  @override
  String get plusFeature1 => '包含所有 Free 版功能';

  @override
  String get plusFeature2 => '免配置直接使用平台高质量 AI 模型';

  @override
  String get plusFeature3 => '每日 50 次平台 AI 调用额度';

  @override
  String get plusFeature4 => '支持自定义 AI 指令管理';

  @override
  String get upgradeNow => '立即升级';

  @override
  String get proPlan => 'Pro 终极版';

  @override
  String get proPrice => '￥45 / 月';

  @override
  String get proFeature1 => '包含所有 Plus 版功能';

  @override
  String get proFeature2 => '每日 500 次平台高级 AI 调用额度';

  @override
  String get proFeature3 => '高级主题定制 (即将推出)';

  @override
  String get proFeature4 => '优先客服支持';

  @override
  String get currentBadge => '当前';

  @override
  String get accountManagement => '账户管理';

  @override
  String get roleAdmin => '管理员';

  @override
  String get roleUser => '普通用户';

  @override
  String get email => '邮箱';

  @override
  String get emailNotSet => '未设置';

  @override
  String get registrationTime => '注册时间';

  @override
  String get accountStatus => '账户状态';

  @override
  String get statusActive => '正常';

  @override
  String get statusDisabled => '已禁用';

  @override
  String get accountOperations => '账户操作';

  @override
  String get changeEmail => '修改邮箱';

  @override
  String get newEmailLabel => '新邮箱地址';

  @override
  String get newEmailHint => '请输入新的邮箱地址';

  @override
  String get emailEmpty => '邮箱不能为空';

  @override
  String get emailUpdateSuccess => '邮箱修改成功';

  @override
  String get changePassword => '修改密码';

  @override
  String get currentPassword => '当前密码';

  @override
  String get currentPasswordHint => '请输入当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get newPasswordHint => '至少 6 个字符';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get confirmNewPasswordHint => '再次输入新密码';

  @override
  String get fillAllPasswordFields => '请填写所有密码字段';

  @override
  String get newPasswordMinChars => '新密码至少需要 6 个字符';

  @override
  String get passwordsMismatch => '两次输入的新密码不一致';

  @override
  String get passwordUpdateSuccess => '密码修改成功';

  @override
  String get logoutConfirm => '确认退出';

  @override
  String get logoutConfirmContent => '确定要退出登录吗？';

  @override
  String get logout => '退出';

  @override
  String get logoutButton => '退出登录';

  @override
  String get changeEmailAction => '修改邮箱';

  @override
  String get changePasswordAction => '修改密码';

  @override
  String get changePasswordSubtitle => '定期更换密码可提高账户安全';

  @override
  String get dailyDigestTitle => 'AI 每日简报';

  @override
  String get regenerate => '重新生成';

  @override
  String get readingAllUnread => '正在阅读所有未读文章...\nAI 编辑部正在为您撰写今日简报';

  @override
  String get generationFailed => '生成失败';

  @override
  String get noArticlesForDigest => '暂无最新文章可供生成简报';

  @override
  String referenceSource(Object index) {
    return '来源 [$index]';
  }

  @override
  String get readOriginal => '阅读原文';

  @override
  String get aiSynthesis => 'AI 聚合';

  @override
  String get ttsComingSoon => '即将推出 TTS 朗读功能';

  @override
  String readingChannelArticles(Object channelName) {
    return '正在阅读 $channelName 近期文章...\nAI 正在为您生成聚合分析报告';
  }

  @override
  String get synthesisFailed => '生成失败';

  @override
  String get noArticlesToAnalyze => '没有可分析的文章';

  @override
  String reference(Object index) {
    return '引用 [$index]';
  }

  @override
  String get userManagementTitle => '用户管理';

  @override
  String get noUsers => '暂无用户';

  @override
  String get editUser => '编辑用户';

  @override
  String get role => '角色';

  @override
  String get membershipTier => '会员等级';

  @override
  String get isActive => '状态';

  @override
  String get active => '正常';

  @override
  String get disabled => '已禁用';

  @override
  String get userUpdated => '用户更新成功';

  @override
  String get updateUserFailed => '更新用户失败';

  @override
  String get deleteUser => '删除用户';

  @override
  String deleteUserConfirm(Object name) {
    return '确定要删除用户 \"$name\" 吗？';
  }

  @override
  String get userDeleted => '用户已删除';

  @override
  String get deleteUserFailed => '删除用户失败';

  @override
  String get healthCheck => '服务器状态检测';

  @override
  String get serverOnline => '服务器连接正常';

  @override
  String get serverOffline => '无法连接到服务器';

  @override
  String get checkNow => '立即检测';

  @override
  String get dateFormatYear => '年';

  @override
  String get dateFormatMonth => '月';

  @override
  String get dateFormatDay => '日';

  @override
  String readCount(Object count) {
    return '$count 篇文章';
  }

  @override
  String get defaultValue => '默认';
}
