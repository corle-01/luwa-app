/// App-wide constants
class AppConstants {
  // App
  static const String appName = 'Haru Koffie';
  static const String appSlogan = 'AI Business Co-Pilot';

  // Database table names
  static const String tableOutlets = 'outlets';
  static const String tableProfiles = 'profiles';
  static const String tableProducts = 'products';
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';
  static const String tableIngredients = 'ingredients';
  static const String tableRecipes = 'recipes';
  static const String tableStockMovements = 'stock_movements';
  static const String tablePurchaseOrders = 'purchase_orders';
  static const String tableShifts = 'shifts';
  static const String tableCustomers = 'customers';
  static const String tableDiscounts = 'discounts';

  // AI Tables
  static const String tableAITrustSettings = 'ai_trust_settings';
  static const String tableAIConversations = 'ai_conversations';
  static const String tableAIMessages = 'ai_messages';
  static const String tableAIActionLogs = 'ai_action_logs';
  static const String tableAIInsights = 'ai_insights';

  // AI Trust Levels
  static const int trustLevelInform = 0; // Inform Only
  static const int trustLevelSuggest = 1; // Suggest + Confirm
  static const int trustLevelAuto = 2; // Auto + Notify
  static const int trustLevelSilent = 3; // Full Auto (Silent)

  // AI Feature Keys
  static const String featureStockAlert = 'stock_alert';
  static const String featureAutoDisableProduct = 'auto_disable_product';
  static const String featureAutoEnableProduct = 'auto_enable_product';
  static const String featureDraftPurchaseOrder = 'draft_purchase_order';
  static const String featureSendPurchaseOrder = 'send_purchase_order';
  static const String featureDemandForecast = 'demand_forecast';
  static const String featurePricingRecommendation = 'pricing_recommendation';
  static const String featureAutoPromo = 'auto_promo';
  static const String featureAnomalyAlert = 'anomaly_alert';
  static const String featureStaffingSuggestion = 'staffing_suggestion';
  static const String featureAutoReorder = 'auto_reorder';
  static const String featureMenuRecommendation = 'menu_recommendation';

  // DeepSeek API
  static const String deepseekBaseUrl = 'https://api.deepseek.com/v1';
  static const String deepseekModelChat = 'deepseek-chat';
  static const String deepseekModelReasoner = 'deepseek-reasoner';

  // Date formats
  static const String dateFormatDisplay = 'dd MMM yyyy';
  static const String dateFormatApi = 'yyyy-MM-dd';
  static const String dateTimeFormatDisplay = 'dd MMM yyyy HH:mm';
  static const String timeFormatDisplay = 'HH:mm';

  // Currency
  static const String currencySymbol = 'Rp';
  static const String currencyCode = 'IDR';
  static const String locale = 'id_ID';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration aiTimeout = Duration(seconds: 60);

  // Cache
  static const Duration cacheExpiration = Duration(hours: 1);

  // Storage keys
  static const String keyToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyOutletId = 'outlet_id';
  static const String keyUserRole = 'user_role';

  // User roles
  static const String roleOwner = 'owner';
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleCashier = 'cashier';
  static const String roleKitchen = 'kitchen';

  // Order status
  static const String orderStatusDraft = 'draft';
  static const String orderStatusPending = 'pending';
  static const String orderStatusPreparing = 'preparing';
  static const String orderStatusReady = 'ready';
  static const String orderStatusCompleted = 'completed';
  static const String orderStatusCancelled = 'cancelled';
  static const String orderStatusRefunded = 'refunded';

  // Payment methods
  static const String paymentCash = 'cash';
  static const String paymentCard = 'card';
  static const String paymentQris = 'qris';
  static const String paymentEwallet = 'ewallet';
  static const String paymentTransfer = 'bank_transfer';

  // Insight severity
  static const String severityInfo = 'info';
  static const String severityWarning = 'warning';
  static const String severityCritical = 'critical';
  static const String severityPositive = 'positive';

  // AI action types
  static const String actionInformed = 'informed';
  static const String actionSuggested = 'suggested';
  static const String actionAutoExecuted = 'auto_executed';
  static const String actionSilentExecuted = 'silent_executed';
  static const String actionApproved = 'approved';
  static const String actionRejected = 'rejected';
  static const String actionEdited = 'edited';
  static const String actionUndone = 'undone';

  // Undo window
  static const Duration undoWindow = Duration(minutes: 30);
}
