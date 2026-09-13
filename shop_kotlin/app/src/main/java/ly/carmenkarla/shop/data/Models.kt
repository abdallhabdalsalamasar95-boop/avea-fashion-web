package ly.carmenkarla.shop.data

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/** The catalog is loose JSON, so lists and numbers can arrive in several shapes. */
private fun splitLoose(raw: String) =
    raw.split(',', '،', '|').map { it.trim() }.filter { it.isNotEmpty() }

object LenientStringList : KSerializer<List<String>> {
    private val delegate = ListSerializer(String.serializer())
    override val descriptor: SerialDescriptor = delegate.descriptor
    override fun deserialize(decoder: Decoder): List<String> {
        val input = decoder as? JsonDecoder ?: return emptyList()
        return when (val element = input.decodeJsonElement()) {
            is JsonArray -> element.mapNotNull { (it as? JsonPrimitive)?.contentOrNull?.trim() }
                .filter { it.isNotEmpty() }
            is JsonPrimitive -> splitLoose(element.contentOrNull.orEmpty())
            else -> emptyList()
        }
    }
    override fun serialize(encoder: Encoder, value: List<String>) = delegate.serialize(encoder, value)
}

object LenientIntMap : KSerializer<Map<String, Int>> {
    private val delegate = MapSerializer(String.serializer(), Int.serializer())
    override val descriptor: SerialDescriptor = delegate.descriptor
    override fun deserialize(decoder: Decoder): Map<String, Int> {
        val input = decoder as? JsonDecoder ?: return emptyMap()
        val element = input.decodeJsonElement() as? JsonObject ?: return emptyMap()
        return element.mapNotNull { (key, raw) ->
            val number = (raw as? JsonPrimitive)?.contentOrNull?.toDoubleOrNull() ?: return@mapNotNull null
            key to number.toInt()
        }.toMap()
    }
    override fun serialize(encoder: Encoder, value: Map<String, Int>) = delegate.serialize(encoder, value)
}

object LenientDouble : KSerializer<Double> {
    override val descriptor: SerialDescriptor = Double.serializer().descriptor
    override fun deserialize(decoder: Decoder): Double {
        val input = decoder as? JsonDecoder ?: return 0.0
        val primitive = input.decodeJsonElement() as? JsonPrimitive ?: return 0.0
        return primitive.contentOrNull?.toDoubleOrNull() ?: 0.0
    }
    override fun serialize(encoder: Encoder, value: Double) = encoder.encodeDouble(value)
}

object LenientInt : KSerializer<Int> {
    override val descriptor: SerialDescriptor = Int.serializer().descriptor
    override fun deserialize(decoder: Decoder): Int {
        val input = decoder as? JsonDecoder ?: return 0
        val primitive = input.decodeJsonElement() as? JsonPrimitive ?: return 0
        return primitive.contentOrNull?.toDoubleOrNull()?.toInt() ?: 0
    }
    override fun serialize(encoder: Encoder, value: Int) = encoder.encodeInt(value)
}

@Serializable
data class Product(
    val id: String = "",
    val name: String = "",
    val description: String = "",
    val category: String = "",
    val productCode: String = "",
    @Serializable(with = LenientDouble::class) val price: Double = 0.0,
    @Serializable(with = LenientDouble::class) val oldPrice: Double = 0.0,
    val imageUrl: String = "",
    @Serializable(with = LenientStringList::class) val imageUrls: List<String> = emptyList(),
    @Serializable(with = LenientStringList::class) val colors: List<String> = emptyList(),
    @Serializable(with = LenientStringList::class) val sizes: List<String> = emptyList(),
    @Serializable(with = LenientIntMap::class) val sizeQuantities: Map<String, Int> = emptyMap(),
    @Serializable(with = LenientInt::class) val availableStock: Int = 0,
    @Serializable(with = LenientInt::class) val outOfStock: Int = 0,
    @Serializable(with = LenientInt::class) val isHidden: Int = 0,
    @Serializable(with = LenientInt::class) val soldPieces: Int = 0,
    @Serializable(with = LenientDouble::class) val commissionPercent: Double = 0.0,
    @Serializable(with = LenientInt::class) val wholesaleEnabled: Int = 0,
    @Serializable(with = LenientDouble::class) val wholesalePrice: Double = 0.0,
    @Serializable(with = LenientInt::class) val wholesaleMinQty: Int = 1,
    val createdAt: Long = 0,
) {
    val gallery: List<String>
        get() = (listOf(imageUrl) + imageUrls).filter { it.isNotBlank() }.distinct()

    val soldOut: Boolean
        get() = outOfStock == 1 || availableStock == 0

    /** Sizes the customer can actually order right now, ordered ascending. */
    val availableSizes: List<String>
        get() = sizes.filter { (sizeQuantities[it] ?: 1) > 0 }
            .sortedWith(compareBy({ it.toIntOrNull() ?: Int.MAX_VALUE }, { it }))

    val discountPercent: Int
        get() = if (oldPrice > price && oldPrice > 0) (((oldPrice - price) / oldPrice) * 100).toInt() else 0

    /** Pieces the warehouse still holds for the chosen size, or for the product as a whole. */
    fun stockFor(size: String): Int {
        if (outOfStock == 1) return 0
        if (size.isNotBlank() && sizeQuantities.containsKey(size)) return sizeQuantities.getValue(size).coerceAtLeast(0)
        if (sizeQuantities.isNotEmpty() && sizes.isNotEmpty()) {
            return sizeQuantities.values.sumOf { it.coerceAtLeast(0) }
        }
        return availableStock.coerceAtLeast(0)
    }

    val hasWholesale: Boolean
        get() = wholesaleEnabled == 1 && wholesalePrice > 0 && wholesalePrice < price

    val wholesaleThreshold: Int
        get() = wholesaleMinQty.coerceAtLeast(2)

    /** Bulk buyers pay the wholesale rate once they reach the minimum quantity. */
    fun unitPriceFor(quantity: Int): Double =
        if (hasWholesale && quantity >= wholesaleThreshold) wholesalePrice else price

    val wholesaleSavingPercent: Int
        get() = if (hasWholesale) (((price - wholesalePrice) / price) * 100).toInt() else 0
}

@Serializable
data class ProductsResponse(
    val items: List<Product> = emptyList(),
)

@Serializable
data class DestinationsResponse(
    val ok: Boolean = true,
    val providerAvailable: Boolean = true,
    val cities: Map<String, List<String>> = emptyMap(),
)

@Serializable
data class ShippingQuoteResponse(
    val ok: Boolean = true,
    @Serializable(with = LenientDouble::class) val amount: Double = 0.0,
    val source: String = "fallback",
    val providerAvailable: Boolean = false,
)

@Serializable
data class OrderResponse(
    val ok: Boolean = true,
    val orderId: String = "",
    val trackingToken: String = "",
    val error: String = "",
)

/** A configured line in the cart; lineId keeps identical products with different options apart. */
@Serializable
data class CartLine(
    val lineId: String,
    val productId: String,
    val productCode: String,
    val name: String,
    val price: Double,
    val imageUrl: String,
    val size: String = "",
    val color: String = "",
    val quantity: Int = 1,
    /** Pieces available in the warehouse for this size; 0 means unknown. */
    val stockLimit: Int = 0,
    @Serializable(with = LenientDouble::class) val wholesalePrice: Double = 0.0,
    @Serializable(with = LenientInt::class) val wholesaleMinQty: Int = 0,
) {
    val usesWholesale: Boolean
        get() = wholesalePrice > 0 && wholesaleMinQty > 0 && quantity >= wholesaleMinQty

    val unitPrice: Double get() = if (usesWholesale) wholesalePrice else price

    val lineTotal: Double get() = unitPrice * quantity
}

@Serializable
data class CustomerDetails(
    val name: String = "",
    val phone: String = "",
    val city: String = "",
    val area: String = "",
    val address: String = "",
)

data class TrackedOrder(
    val orderId: String,
    val trackingToken: String,
    val total: Double,
    val itemCount: Int,
    val createdAt: Long,
)

/** A order placed from this device; the token is what lets us read its status back. */
@Serializable
data class SavedOrderLine(
    val productId: String = "",
    val productCode: String = "",
    val name: String = "",
    val imageUrl: String = "",
    val size: String = "",
    val color: String = "",
    @Serializable(with = LenientInt::class) val quantity: Int = 1,
    @Serializable(with = LenientDouble::class) val price: Double = 0.0,
)

@Serializable
data class SavedOrder(
    val orderId: String = "",
    val trackingToken: String = "",
    val total: Double = 0.0,
    val itemCount: Int = 0,
    val createdAtMs: Long = 0,
    val summary: String = "",
    val items: List<SavedOrderLine> = emptyList(),
    val city: String = "",
    val address: String = "",
    val shipping: Double = 0.0,
    val notifiedStatus: String = "pending",
)

@Serializable
data class TrackingDelivery(
    val status: String = "",
    val trackingNumber: String = "",
    val referenceCode: String = "",
    val providerStatus: String = "",
    val courierPhone: String = "",
)

@Serializable
data class TrackingItem(
    val orderId: String = "",
    val status: String = "pending",
    val createdAtMs: Long = 0,
    val updatedAtMs: Long = 0,
    val ambassadorPhone: String = "",
    val statusReason: String = "",
    val statusReasonImageUrl: String = "",
    val externalDelivery: TrackingDelivery = TrackingDelivery(),
    val trackingToken: String = "",
)

@Serializable
data class TrackingResponse(
    val ok: Boolean = false,
    val error: String = "",
    val item: TrackingItem? = null,
)

/** An order read back from the server for a signed-in customer. */
@Serializable
data class AccountOrder(
    val orderId: String = "",
    val status: String = "pending",
    @Serializable(with = LenientDouble::class) val total: Double = 0.0,
    @Serializable(with = LenientInt::class) val itemCount: Int = 0,
    val createdAtMs: Long = 0,
    val externalDelivery: TrackingDelivery = TrackingDelivery(),
    val trackingToken: String = "",
)

@Serializable
data class AccountOrdersResponse(
    val ok: Boolean = true,
    val items: List<AccountOrder> = emptyList(),
)

/** Home content the admin manages; shared with the website. */
@Serializable
data class Announcement(
    val enabled: Boolean = true,
    val text: String = "",
)

@Serializable
data class HomeBanner(
    val enabled: Boolean = true,
    val imageUrl: String = "",
    val altText: String = "",
)

@Serializable
data class HomeCategory(
    val id: String = "",
    val title: String = "",
    val imageUrl: String = "",
    val productCategoryFilter: String = "",
    val enabled: Boolean = true,
)

@Serializable
data class WebsiteHome(
    val announcement: Announcement = Announcement(),
    val banner: HomeBanner = HomeBanner(),
    val sectionBanner: HomeBanner = HomeBanner(),
    val categories: List<HomeCategory> = emptyList(),
)

@Serializable
data class CommissionConfig(
    @Serializable(with = LenientDouble::class) val defaultPercent: Double = 7.0,
    val perProductEnabled: Boolean = true,
) {
    /** Mirrors the storefront rule: a per-product rate wins, otherwise the shop default. */
    fun rateFor(product: Product): Double {
        val own = product.commissionPercent
        val rate = if (perProductEnabled && own > 0) own else defaultPercent
        return rate.coerceIn(0.0, 100.0)
    }

    fun amountFor(product: Product, quantity: Int = 1): Double =
        product.price * quantity * rateFor(product) / 100.0
}

@Serializable
data class SupportContact(
    val enabled: Boolean = true,
    val whatsappNumber: String = "",
)

@Serializable
data class WholesaleSettings(
    val enabled: Boolean = false,
    val title: String = "قسم الجملة",
    val subtitle: String = "",
    val note: String = "",
    @Serializable(with = LenientInt::class) val defaultMinQty: Int = 6,
    val whatsappNumber: String = "",
)

@Serializable
data class AppContent(
    val websiteHome: WebsiteHome = WebsiteHome(),
    val commission: CommissionConfig = CommissionConfig(),
    val ambassadorSupport: SupportContact = SupportContact(),
    val wholesale: WholesaleSettings = WholesaleSettings(),
)

@Serializable
data class AmbassadorProfile(
    val uid: String = "",
    val accountRole: String = "",
    val ambassadorName: String = "",
    val ambassadorPhone: String = "",
    val ambassadorAddress: String = "",
    val email: String = "",
    val status: String = "active",
    val joinedAt: Long = 0,
) {
    val isActive: Boolean
        get() = accountRole.equals("ambassador", true) && status.equals("active", true)
}

@Serializable
data class AmbassadorProfileResponse(
    val ok: Boolean = true,
    val error: String = "",
    val profile: AmbassadorProfile? = null,
)

@Serializable
data class AmbassadorOrderSummary(
    @Serializable(with = LenientDouble::class) val estimatedCommission: Double = 0.0,
    @Serializable(with = LenientDouble::class) val commissionTotal: Double = 0.0,
    @Serializable(with = LenientDouble::class) val grossSales: Double = 0.0,
    @Serializable(with = LenientDouble::class) val commissionPercent: Double = 0.0,
) {
    val commission: Double get() = if (commissionTotal > 0) commissionTotal else estimatedCommission
}

@Serializable
data class AmbassadorOrderPayload(
    val items: List<SavedOrderLine> = emptyList(),
)

@Serializable
data class AmbassadorOrder(
    val orderId: String = "",
    val status: String = "pending",
    val createdAtMs: Long = 0,
    val trackingToken: String = "",
    val customerName: String = "",
    val customerPhone: String = "",
    val customerAddress: String = "",
    val customerCity: String = "",
    val statusReason: String = "",
    @Serializable(with = LenientDouble::class) val grandTotal: Double = 0.0,
    @Serializable(with = LenientInt::class) val itemsCount: Int = 0,
    val payload: AmbassadorOrderPayload = AmbassadorOrderPayload(),
    val ambassadorSummary: AmbassadorOrderSummary = AmbassadorOrderSummary(),
    val externalDelivery: TrackingDelivery = TrackingDelivery(),
) {
    /** Commission is only banked once the parcel is actually delivered. */
    val isEarning: Boolean get() = status == "delivered"
    val isCancelable: Boolean get() = status == "pending" || status == "processing"
}

@Serializable
data class AmbassadorOrdersResponse(
    val ok: Boolean = true,
    val count: Int = 0,
    val items: List<AmbassadorOrder> = emptyList(),
)

@Serializable
data class WithdrawalRequest(
    val id: String = "",
    @Serializable(with = LenientDouble::class) val amount: Double = 0.0,
    val status: String = "pending",
    val createdAtMs: Long = 0,
)

@Serializable
data class WithdrawalSummary(
    val ok: Boolean = true,
    val error: String = "",
    val code: String = "",
    @Serializable(with = LenientDouble::class) val minimum: Double = 100.0,
    @Serializable(with = LenientDouble::class) val earned: Double = 0.0,
    @Serializable(with = LenientDouble::class) val reserved: Double = 0.0,
    @Serializable(with = LenientDouble::class) val available: Double = 0.0,
    @Serializable(with = LenientDouble::class) val remainingToMinimum: Double = 0.0,
    val canRequest: Boolean = false,
    val pendingRequest: WithdrawalRequest? = null,
    val requests: List<WithdrawalRequest> = emptyList(),
)

@Serializable
data class SimpleResponse(
    val ok: Boolean = true,
    val error: String = "",
    /** Presence endpoints use this to tell the client to stop pinging. */
    val enabled: Boolean = true,
)

@Serializable
data class AmbassadorShare(
    val ok: Boolean = true,
    val token: String = "",
    val ambassadorName: String = "",
    val expiresAt: Long = 0,
)

@Serializable
data class SharedCartSelection(
    val productId: String = "",
    val size: String = "",
    val color: String = "",
    @Serializable(with = LenientInt::class) val quantity: Int = 1,
)

object WithdrawalStatusLabels {
    private val map = mapOf(
        "pending" to "قيد المراجعة",
        "approved" to "تمت الموافقة",
        "paid" to "تم الدفع",
        "rejected" to "مرفوض",
    )

    fun of(status: String): String = map[status] ?: status
}

/** Arabic labels for the statuses the backend can report. */
object OrderStatusLabels {
    private val map = mapOf(
        "pending" to "قيد الانتظار",
        "processing" to "تم القبول",
        "shipped" to "قيد التوصيل",
        "postponed" to "مؤجل",
        "delivered" to "تم التوصيل",
        "returning" to "قيد الإرجاع",
        "returned" to "مُرجع",
        "canceled" to "ملغي",
    )

    fun of(status: String): String = map[status] ?: status

    val steps = listOf("pending", "processing", "shipped", "delivered")

    val stepLabels = listOf("قيد الانتظار", "تم القبول", "قيد التوصيل", "تم التوصيل")
}
