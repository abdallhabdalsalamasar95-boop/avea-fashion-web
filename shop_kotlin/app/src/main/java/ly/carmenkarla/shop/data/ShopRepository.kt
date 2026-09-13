package ly.carmenkarla.shop.data

import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import retrofit2.HttpException
import retrofit2.Retrofit
import java.util.concurrent.TimeUnit

/** Matches the shipping table the backend applies when the order is priced. */
private val SHIPPING_COSTS = mapOf(
    "طرابلس" to 10.0,
    "بنغازي" to 15.0,
    "مصراتة" to 12.0,
    "سبها" to 20.0,
    "الزاوية" to 12.0,
    "سرت" to 18.0,
    "درنة" to 18.0,
    "طبرق" to 20.0,
    "جالو اوجلة" to 50.0,
    "جالو أوجلة" to 50.0,
)
private const val DEFAULT_SHIPPING = 25.0
// Single source of truth for the storefront domain; update here only if the Render service is renamed.
internal const val STOREFRONT_URL = "https://karmencarla.onrender.com"

class ShopRepository(private val baseUrl: String) {

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
        explicitNulls = false
    }

    private val api: ShopApi by lazy {
        val client = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(90, TimeUnit.SECONDS)
            .build()
        Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create(ShopApi::class.java)
    }

    suspend fun products(): List<Product> = withContext(Dispatchers.IO) {
        // Skip unpriced rows; they would otherwise be orderable for 0 د.ل.
        api.products().items.filter { it.id.isNotBlank() && it.isHidden != 1 && it.price > 0 }
    }

    suspend fun destinations(): Map<String, List<String>> = withContext(Dispatchers.IO) {
        api.destinations().cities.mapValues { (_, areas) ->
            areas.map { if (it == "المدينة القديمة") "المدينة" else it }.distinct()
        }
    }

    suspend fun homeContent(): WebsiteHome = withContext(Dispatchers.IO) {
        runCatching { api.appContent().websiteHome }.getOrDefault(WebsiteHome())
    }

    suspend fun appContent(): AppContent = withContext(Dispatchers.IO) {
        runCatching { api.appContent() }.getOrDefault(AppContent())
    }

    /** "Someone is browsing" signal; returns false when the admin turned tracking off. */
    suspend fun presencePing(
        sessionId: String,
        uid: String,
        name: String,
        city: String,
        screen: String,
    ): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            api.presencePing(
                JsonObject(
                    mapOf(
                        "sid" to JsonPrimitive(sessionId),
                        "platform" to JsonPrimitive("android"),
                        "uid" to JsonPrimitive(uid),
                        "name" to JsonPrimitive(name),
                        "city" to JsonPrimitive(city),
                        "screen" to JsonPrimitive(screen),
                    ),
                ),
            )
        }.map { it.enabled }.getOrDefault(true)
    }

    fun productLink(productId: String, shareToken: String = ""): String {
        val id = java.net.URLEncoder.encode(productId, "UTF-8")
        val ref = if (shareToken.isBlank()) "" else "&ref=" + java.net.URLEncoder.encode(shareToken, "UTF-8")
        return "$STOREFRONT_URL/product/?id=$id$ref"
    }

    /** Same base64url cart payload the storefront's /shared-order/ page decodes. */
    fun sharedCartLink(lines: List<CartLine>, shareToken: String = ""): String {
        val selections = JsonArray(
            lines.map { line ->
                JsonObject(
                    buildMap {
                        put("productId", JsonPrimitive(line.productId))
                        if (line.size.isNotBlank()) put("size", JsonPrimitive(line.size))
                        if (line.color.isNotBlank()) put("color", JsonPrimitive(line.color))
                        put("quantity", JsonPrimitive(line.quantity.coerceAtLeast(1)))
                    },
                )
            },
        )
        val encoded = android.util.Base64.encodeToString(
            selections.toString().toByteArray(Charsets.UTF_8),
            android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP,
        )
        val ref = if (shareToken.isBlank()) "" else "ref=" + java.net.URLEncoder.encode(shareToken, "UTF-8") + "&"
        return "$STOREFRONT_URL/shared-order/?$ref" + "cart=$encoded"
    }

    suspend fun shareToken(idToken: String): String = withContext(Dispatchers.IO) {
        runCatching { api.ambassadorShareToken("Bearer $idToken").token }.getOrDefault("")
    }

    suspend fun shippingFor(city: String, area: String = "", address: String = ""): Double = withContext(Dispatchers.IO) {
        val normalizedCity = city.trim()
        val fallback = SHIPPING_COSTS[normalizedCity] ?: DEFAULT_SHIPPING
        if (normalizedCity.isBlank()) return@withContext 0.0
        runCatching {
            api.shippingCost(normalizedCity, area.trim(), address.trim()).amount
        }.map { it.coerceAtLeast(0.0) }.getOrDefault(fallback)
    }

    suspend fun tracking(orderId: String, token: String): TrackingItem = withContext(Dispatchers.IO) {
        val response = api.tracking(orderId, token)
        response.item ?: error(response.error.ifBlank { "تعذر العثور على بيانات التتبع" })
    }

    fun absoluteUrl(url: String): String {
        if (url.isBlank() || url.startsWith("http")) return url
        val base = baseUrl.trimEnd('/')
        return base + if (url.startsWith("/")) url else "/$url"
    }

    suspend fun submitOrder(
        customer: CustomerDetails,
        lines: List<CartLine>,
        note: String,
        idToken: String = "",
        uid: String = "",
        ambassador: AmbassadorProfile? = null,
        ambassadorShareToken: String = "",
    ): OrderResponse = withContext(Dispatchers.IO) {
        val subtotal = lines.sumOf { it.lineTotal }
        val shipping = shippingFor(customer.city, customer.area)

        val items = JsonArray(
            lines.map { line ->
                JsonObject(
                    mapOf(
                        "productId" to JsonPrimitive(line.productId),
                        "productCode" to JsonPrimitive(line.productCode),
                        "name" to JsonPrimitive(line.name),
                        "price" to JsonPrimitive(line.unitPrice),
                        "listPrice" to JsonPrimitive(line.price),
                        "wholesale" to JsonPrimitive(line.usesWholesale),
                        "imageUrl" to JsonPrimitive(line.imageUrl),
                        "size" to JsonPrimitive(line.size),
                        "color" to JsonPrimitive(line.color),
                        "quantity" to JsonPrimitive(line.quantity),
                    ),
                )
            },
        )

        val placedByAmbassador = ambassador?.isActive == true
        val customerFields = buildMap<String, JsonElement> {
            put("name", JsonPrimitive(customer.name))
            put("phone", JsonPrimitive(customer.phone))
            put("city", JsonPrimitive(customer.city))
            put("area", JsonPrimitive(customer.area))
            put("address", JsonPrimitive(customer.address))
            put("accountRole", JsonPrimitive(if (placedByAmbassador) "ambassador" else "customer"))
            if (placedByAmbassador) {
                put("placedAsAmbassador", JsonPrimitive(true))
                put("submitterUid", JsonPrimitive(ambassador.uid.ifBlank { uid }))
                put("submitterName", JsonPrimitive(ambassador.ambassadorName))
                put("submitterPhone", JsonPrimitive(ambassador.ambassadorPhone))
                put("submitterEmail", JsonPrimitive(ambassador.email))
            }
        }

        val payload: Map<String, JsonElement> = mapOf(
            "customer" to JsonObject(customerFields),
            "items" to items,
            "pricing" to JsonObject(
                mapOf(
                    "subtotal" to JsonPrimitive(subtotal),
                    "discount" to JsonPrimitive(0.0),
                    "shippingCost" to JsonPrimitive(shipping),
                    // Shipping is collected separately by the courier, not by the store.
                    "grandTotal" to JsonPrimitive(subtotal),
                ),
            ),
            "paymentMethod" to JsonPrimitive("الدفع عند الاستلام"),
            "note" to JsonPrimitive(note),
        )

        val rootPayload = buildMap<String, JsonElement> {
            put("orderId", JsonPrimitive("o_${System.currentTimeMillis()}"))
            put("status", JsonPrimitive("pending"))
            put("source", JsonPrimitive("android"))
            put("uid", JsonPrimitive(uid))
            put("payload", JsonObject(payload))
            if (ambassadorShareToken.isNotBlank()) {
                put("ambassadorShareToken", JsonPrimitive(ambassadorShareToken.trim()))
            }
        }

        val body = JsonObject(rootPayload)

        val response = api.submitOrder(body, idToken.takeIf { it.isNotBlank() }?.let { "Bearer $it" })
        if (!response.ok) error(response.error.ifBlank { "تعذر إرسال الطلب" })
        response
    }

    suspend fun accountOrders(idToken: String): List<AccountOrder> = withContext(Dispatchers.IO) {
        api.accountOrders("Bearer $idToken").items
    }
    
        suspend fun saveCustomerProfile(idToken: String, customer: CustomerDetails) = withContext(Dispatchers.IO) {
            val body = JsonObject(
                mapOf(
                    "name" to JsonPrimitive(customer.name.trim()),
                    "phone" to JsonPrimitive(customer.phone.trim()),
                    "city" to JsonPrimitive(customer.city.trim()),
                    "area" to JsonPrimitive(customer.area.trim()),
                    "address" to JsonPrimitive(customer.address.trim()),
                ),
            )
            val response = api.saveCustomerProfile("Bearer $idToken", body)
            if (!response.ok) error(response.error.ifBlank { "تعذر حفظ بيانات الحساب" })
        }

    suspend fun ambassadorProfile(idToken: String): AmbassadorProfile? = withContext(Dispatchers.IO) {
        call { api.ambassadorProfile("Bearer $idToken").profile?.takeIf { it.isActive } }
    }

    suspend fun saveAmbassadorProfile(
        idToken: String,
        name: String,
        phone: String,
        address: String,
    ): AmbassadorProfile = withContext(Dispatchers.IO) {
        val body = JsonObject(
            mapOf(
                "ambassadorName" to JsonPrimitive(name.trim()),
                "ambassadorPhone" to JsonPrimitive(phone.trim()),
                "ambassadorAddress" to JsonPrimitive(address.trim()),
            ),
        )
        val response = call { api.saveAmbassadorProfile("Bearer $idToken", body) }
        response.profile ?: error(response.error.ifBlank { "تعذر حفظ بيانات المندوبة" })
    }

    suspend fun ambassadorOrders(idToken: String): List<AmbassadorOrder> = withContext(Dispatchers.IO) {
        call { api.ambassadorOrders("Bearer $idToken").items }
    }

    suspend fun cancelAmbassadorOrder(idToken: String, orderId: String) = withContext(Dispatchers.IO) {
        call { api.cancelAmbassadorOrder(orderId, "Bearer $idToken") }
        Unit
    }

    suspend fun ambassadorWithdrawals(idToken: String): WithdrawalSummary = withContext(Dispatchers.IO) {
        call { api.ambassadorWithdrawals("Bearer $idToken") }
    }

    suspend fun requestWithdrawal(idToken: String): WithdrawalSummary = withContext(Dispatchers.IO) {
        call { api.requestWithdrawal("Bearer $idToken") }
    }

    /** Returns the storefront link that attributes any resulting order to this ambassador. */
    suspend fun ambassadorShareLink(idToken: String): String = withContext(Dispatchers.IO) {
        val share = call { api.ambassadorShareToken("Bearer $idToken") }
        if (share.token.isBlank()) error("تعذر إنشاء رابط المشاركة")
        "$STOREFRONT_URL/?ref=" + java.net.URLEncoder.encode(share.token, "UTF-8")
    }

    /** Surfaces the backend's Arabic `error` field instead of a bare "HTTP 403". */
    private inline fun <T> call(block: () -> T): T = try {
        block()
    } catch (ex: HttpException) {
        val raw = ex.response()?.errorBody()?.string().orEmpty()
        val message = runCatching {
            (json.parseToJsonElement(raw) as JsonObject)["error"]?.jsonPrimitive?.content
        }.getOrNull()
        error(message?.takeIf { it.isNotBlank() } ?: "تعذر إتمام العملية (${ex.code()})")
    }
}
