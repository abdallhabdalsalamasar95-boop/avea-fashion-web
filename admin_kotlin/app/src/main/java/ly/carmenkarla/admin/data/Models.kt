package ly.carmenkarla.admin.data

import kotlinx.serialization.Serializable

@Serializable
data class Product(
    val id: String = "",
    val name: String = "",
    val description: String = "",
    val category: String = "",
    val tags: String = "",
    val productCode: String = "",
    @Serializable(with = LenientDouble::class) val price: Double = 0.0,
    @Serializable(with = LenientDouble::class) val oldPrice: Double = 0.0,
    @Serializable(with = LenientDouble::class) val purchasePrice: Double = 0.0,
    val imageUrl: String = "",
    @Serializable(with = LenientStringList::class) val imageUrls: List<String> = emptyList(),
    @Serializable(with = LenientStringList::class) val colors: List<String> = emptyList(),
    @Serializable(with = LenientStringList::class) val sizes: List<String> = emptyList(),
    val sizeType: String = "clothing",
    @Serializable(with = LenientIntMap::class) val sizeQuantities: Map<String, Int> = emptyMap(),
    @Serializable(with = LenientInt::class) val availableStock: Int = 0,
    @Serializable(with = LenientInt::class) val outOfStock: Int = 0,
    @Serializable(with = LenientInt::class) val isHidden: Int = 0,
    @Serializable(with = LenientDouble::class) val commissionPercent: Double = 0.0,
    @Serializable(with = LenientInt::class) val wholesaleEnabled: Int = 0,
    @Serializable(with = LenientDouble::class) val wholesalePrice: Double = 0.0,
    @Serializable(with = LenientInt::class) val wholesaleMinQty: Int = 0,
    @Serializable(with = LenientInt::class) val soldPieces: Int = 0,
    val createdAt: Long = 0,
)

@Serializable
data class ProductsResponse(
    val ok: Boolean = true,
    val total: Int = 0,
    val items: List<Product> = emptyList(),
)

@Serializable
data class UploadResponse(
    val ok: Boolean = false,
    val url: String = "",
    val thumbnailUrl: String = "",
    val error: String = "",
)

@Serializable
data class SimpleResponse(
    val ok: Boolean = false,
    val error: String = "",
)

@Serializable
data class ProductStats(
    val total: Int = 0,
    val visible: Int = 0,
    val hidden: Int = 0,
    val categories: Int = 0,
    val lowStock: Int = 0,
    val outOfStock: Int = 0,
)

@Serializable
data class OrderStats(
    val total: Int = 0,
    val pending: Int = 0,
    val processing: Int = 0,
    val shipped: Int = 0,
    val delivered: Int = 0,
    val canceled: Int = 0,
    val uniqueCustomers: Int = 0,
)

@Serializable
data class UserStats(
    val registered: Int = 0,
    val active1d: Int = 0,
    val active7d: Int = 0,
    val active30d: Int = 0,
)

@Serializable
data class DeviceStats(val installed: Int = 0)

@Serializable
data class PresenceVisitor(
    val name: String = "",
    val city: String = "",
    val screen: String = "",
    val platform: String = "web",
    val signedIn: Boolean = false,
    val secondsHere: Int = 0,
    val secondsAgo: Int = 0,
)

@Serializable
data class PresenceResponse(
    val ok: Boolean = true,
    val enabled: Boolean = true,
    val showNames: Boolean = true,
    val online: Int = 0,
    val onlineApp: Int = 0,
    val onlineWeb: Int = 0,
    val signedIn: Int = 0,
    val lastHour: Int = 0,
    val visitors: List<PresenceVisitor> = emptyList(),
)

@Serializable
data class PresenceSettings(
    val enabled: Boolean = true,
    val showNames: Boolean = true,
)

@Serializable
data class PresenceSettingsResponse(
    val ok: Boolean = true,
    val presence: PresenceSettings = PresenceSettings(),
)

@Serializable
data class DashboardSummary(
    val ok: Boolean = true,
    val products: ProductStats = ProductStats(),
    val orders: OrderStats = OrderStats(),
    val users: UserStats = UserStats(),
    val devices: DeviceStats = DeviceStats(),
)

@Serializable
data class OperationalDashboardSummary(
    val ok: Boolean = true,
    val totalOrders: Int = 0,
    val counts: OperationalOrderCounts = OperationalOrderCounts(),
    val deliveredSalesTotal: Double = 0.0,
    val ambassadorCommissionDelivered: Double = 0.0,
    val inventoryValue: Double = 0.0,
    val needsAcceptance: List<OperationalOrder> = emptyList(),
    val overdue: List<OperationalOrder> = emptyList(),
    val returning: List<OperationalOrder> = emptyList(),
    val lowStock: List<LowStockItem> = emptyList(),
    val alerts: List<DashboardAlert> = emptyList(),
)

@Serializable
data class OperationalOrderCounts(
    val pending: Int = 0,
    val processing: Int = 0,
    val shipped: Int = 0,
    val postponed: Int = 0,
    val delivered: Int = 0,
    val canceled: Int = 0,
    val returning: Int = 0,
    val returned: Int = 0,
)

@Serializable
data class OperationalOrder(
    val orderId: String = "",
    val status: String = "",
    val grandTotal: Double = 0.0,
    val stuckForHours: Double = 0.0,
)

@Serializable
data class LowStockItem(
    val productId: String = "",
    val name: String = "",
    val size: String = "",
    val remaining: Int = 0,
)

@Serializable
data class DashboardAlert(
    val level: String = "",
    val message: String = "",
)

/** Scrolling ticker at the very top of every storefront page. */
@Serializable
data class Announcement(
    val text: String = "",
    val enabled: Boolean = true,
    val speedSeconds: Int = 18,
    val style: String = "rose",
)

/** Large banner under the storefront header. */
@Serializable
data class HomeBanner(
    val imageUrl: String = "",
    val altText: String = "",
    val linkUrl: String = "",
    val enabled: Boolean = true,
)

/** Banner placed between the product rails. */
@Serializable
data class SectionBanner(
    val imageUrl: String = "",
    val altText: String = "",
    val linkUrl: String = "",
    val enabled: Boolean = true,
    val widthMode: String = "full",
    val spacing: String = "tight",
    val height: String = "medium",
)

@Serializable
data class WebsiteHome(
    val announcement: Announcement = Announcement(),
    val banner: HomeBanner = HomeBanner(),
    val sectionBanner: SectionBanner = SectionBanner(),
)

@Serializable
data class WebsiteSocial(
    val enabled: Boolean = true,
    val instagram: String = "",
    val facebook: String = "",
    val whatsapp: String = "",
    val telegram: String = "",
    val tiktok: String = "",
    val website: String = "",
)

@Serializable
data class WholesaleSettings(
    val enabled: Boolean = false,
    val title: String = "قسم الجملة",
    val subtitle: String = "أسعار خاصة عند شراء الكمية",
    val note: String = "",
    @Serializable(with = LenientInt::class) val defaultMinQty: Int = 6,
    val whatsappNumber: String = "",
)

@Serializable
data class ShippingRate(
    val city: String = "",
    val area: String = "",
    @Serializable(with = LenientDouble::class) val cost: Double = 0.0,
)

@Serializable
data class ShippingPricing(
    val mode: String = "darb",
    @Serializable(with = LenientDouble::class) val defaultCost: Double = 25.0,
    val cityRates: List<ShippingRate> = emptyList(),
)

/** The slice of /marketing/config this app edits; everything else is preserved verbatim. */
data class SiteSettings(
    val home: WebsiteHome = WebsiteHome(),
    val social: WebsiteSocial = WebsiteSocial(),
    val wholesale: WholesaleSettings = WholesaleSettings(),
    val shippingPricing: ShippingPricing = ShippingPricing(),
)
