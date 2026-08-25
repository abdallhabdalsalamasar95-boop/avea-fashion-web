package ly.carmenkarla.admin.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.Retrofit
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

private const val MAX_IMAGE_EDGE = 1400
private const val IMAGE_QUALITY = 82

class Repository(private val context: Context) {

    val settings = SettingsStore(context)

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
        explicitNulls = false
    }

    private var cachedBaseUrl = ""
    private var cachedApi: AdminApi? = null

    private suspend fun api(): AdminApi {
        val baseUrl = settings.currentBaseUrl()
        cachedApi?.let { if (cachedBaseUrl == baseUrl) return it }

        val client = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(90, TimeUnit.SECONDS)
            .writeTimeout(90, TimeUnit.SECONDS)
            .addInterceptor { chain ->
                val token = runBlocking { settings.currentToken() }
                val request = chain.request().newBuilder()
                    .apply { if (token.isNotEmpty()) header("Authorization", "Bearer $token") }
                    .build()
                chain.proceed(request)
            }
            .build()

        val created = Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create(AdminApi::class.java)

        cachedBaseUrl = baseUrl
        cachedApi = created
        return created
    }

    fun invalidate() {
        cachedApi = null
        cachedBaseUrl = ""
    }

    suspend fun dashboard(): DashboardSummary = withContext(Dispatchers.IO) { api().dashboard() }

    suspend fun orders(status: String = ""): List<Order> = withContext(Dispatchers.IO) {
        api().orders(status = status).items
    }

    suspend fun setOrderStatus(orderId: String, status: String) = withContext(Dispatchers.IO) {
        val response = api().updateOrderStatus(
            orderId,
            JsonObject(mapOf("status" to JsonPrimitive(status))),
        )
        if (!response.ok) error(response.error.ifBlank { "تعذر تحديث حالة الطلب" })
    }

    suspend fun createExternalSale(
        productId: String,
        quantity: Int,
        salePrice: Double,
        size: String,
        color: String,
        customerName: String,
        customerPhone: String,
    ) = withContext(Dispatchers.IO) {
        val response = api().createExternalSale(
            JsonObject(
                mapOf(
                    "productId" to JsonPrimitive(productId),
                    "quantity" to JsonPrimitive(quantity),
                    "salePrice" to JsonPrimitive(salePrice),
                    "size" to JsonPrimitive(size),
                    "color" to JsonPrimitive(color),
                    "customer" to JsonObject(
                        mapOf(
                            "name" to JsonPrimitive(customerName),
                            "phone" to JsonPrimitive(customerPhone),
                        ),
                    ),
                ),
            ),
        )
        if (!response.ok) error(response.error.ifBlank { "تعذر حفظ المبيعة الخارجية" })
    }

    suspend fun dispatchOrder(orderId: String) = withContext(Dispatchers.IO) {
        val response = api().dispatchToDarbSabeel(orderId)
        if (!response.ok) error(response.error.ifBlank { "تعذر إرسال الطلب لدرب السبيل" })
    }

    suspend fun ambassadors(): AmbassadorsResponse = withContext(Dispatchers.IO) { api().ambassadors() }

    suspend fun customers(activeDays: Int = 60): CustomersResponse =
        withContext(Dispatchers.IO) { api().customers(activeDays) }

    suspend fun presence(): PresenceResponse = withContext(Dispatchers.IO) { api().presence() }

    suspend fun updatePresenceSettings(enabled: Boolean, showNames: Boolean): PresenceSettings =
        withContext(Dispatchers.IO) {
            api().updatePresenceSettings(PresenceSettings(enabled, showNames)).presence
        }

    suspend fun withdrawals(): List<Withdrawal> = withContext(Dispatchers.IO) { api().withdrawals().items }

    suspend fun setWithdrawalStatus(id: String, status: String) = withContext(Dispatchers.IO) {
        val response = api().updateWithdrawalStatus(
            id,
            JsonObject(mapOf("status" to JsonPrimitive(status))),
        )
        if (!response.ok) error(response.error.ifBlank { "تعذر تحديث طلب السحب" })
    }

    suspend fun accounting(fromMs: Long = 0, toMs: Long = 0): AccountingSummary =
        withContext(Dispatchers.IO) { api().accounting(fromMs, toMs).summary }

    suspend fun expenses(): List<Expense> = withContext(Dispatchers.IO) { api().expenses().items }

    suspend fun addExpense(amount: Double, category: String, description: String) = withContext(Dispatchers.IO) {
        val response = api().createExpense(
            JsonObject(
                mapOf(
                    "amount" to JsonPrimitive(amount),
                    "category" to JsonPrimitive(category),
                    "description" to JsonPrimitive(description),
                ),
            ),
        )
        if (!response.ok) error(response.error.ifBlank { "تعذر حفظ المصروف" })
    }

    suspend fun removeExpense(id: String) = withContext(Dispatchers.IO) {
        val response = api().deleteExpense(id)
        if (!response.ok) error(response.error.ifBlank { "تعذر حذف المصروف" })
    }

    suspend fun products(): List<Product> = withContext(Dispatchers.IO) { api().products().items }

    suspend fun saveProduct(id: String, body: JsonObject) = withContext(Dispatchers.IO) {
        if (id.isBlank()) api().createProduct(body) else api().updateProduct(id, body)
    }

    suspend fun deleteProduct(id: String) = withContext(Dispatchers.IO) { api().deleteProduct(id) }

    suspend fun uploadImage(uri: Uri): String = withContext(Dispatchers.IO) {
        val bytes = compressImage(uri)
        val part = MultipartBody.Part.createFormData(
            "image",
            "upload_${System.currentTimeMillis()}.jpg",
            bytes.toRequestBody("image/jpeg".toMediaType()),
        )
        val response = api().uploadImage(part)
        if (!response.ok || response.url.isBlank()) {
            error(response.error.ifBlank { "فشل رفع الصورة" })
        }
        absoluteUrl(response.url)
    }

    /** Phone photos are 6-12 MB; downscale and re-encode so uploads and the storefront stay fast. */
    private fun compressImage(uri: Uri): ByteArray {
        val resolver = context.contentResolver

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val longestEdge = maxOf(bounds.outWidth, bounds.outHeight)
        if (longestEdge <= 0) error("تعذر قراءة الصورة")

        var sample = 1
        while (longestEdge / sample > MAX_IMAGE_EDGE * 2) sample *= 2

        val decoded = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: error("تعذر قراءة الصورة")

        val scale = MAX_IMAGE_EDGE.toFloat() / maxOf(decoded.width, decoded.height)
        val bitmap = if (scale >= 1f) decoded else Bitmap.createScaledBitmap(
            decoded,
            (decoded.width * scale).toInt().coerceAtLeast(1),
            (decoded.height * scale).toInt().coerceAtLeast(1),
            true,
        )

        val rotated = applyExifRotation(uri, bitmap)
        val output = ByteArrayOutputStream()
        rotated.compress(Bitmap.CompressFormat.JPEG, IMAGE_QUALITY, output)
        return output.toByteArray()
    }

    private fun applyExifRotation(uri: Uri, bitmap: Bitmap): Bitmap {
        val orientation = runCatching {
            context.contentResolver.openInputStream(uri)?.use {
                ExifInterface(it).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            } ?: ExifInterface.ORIENTATION_NORMAL
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)

        val degrees = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> return bitmap
        }
        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    suspend fun absoluteUrl(url: String): String {
        if (url.isBlank() || url.startsWith("http")) return url
        val base = settings.currentBaseUrl().trimEnd('/')
        return base + if (url.startsWith("/")) url else "/$url"
    }

    suspend fun siteSettings(): Pair<SiteSettings, JsonObject> = withContext(Dispatchers.IO) {
        val config = api().marketingConfig()["config"]?.jsonObject ?: JsonObject(emptyMap())
        val home = config["websiteHome"]
            ?.let { json.decodeFromJsonElement(WebsiteHome.serializer(), it) }
            ?: WebsiteHome()
        val social = config["websiteSocial"]
            ?.let { json.decodeFromJsonElement(WebsiteSocial.serializer(), it) }
            ?: WebsiteSocial()
        val wholesale = config["wholesale"]
            ?.let { json.decodeFromJsonElement(WholesaleSettings.serializer(), it) }
            ?: WholesaleSettings()
        val shippingPricing = config["shippingPricing"]
            ?.let { json.decodeFromJsonElement(ShippingPricing.serializer(), it) }
            ?: ShippingPricing()
        SiteSettings(home, social, wholesale, shippingPricing) to config
    }

    /** Merges only the edited keys back so coupons, offers and appearance survive the save. */
    suspend fun saveSiteSettings(value: SiteSettings, original: JsonObject) = withContext(Dispatchers.IO) {
        val home = (original["websiteHome"]?.jsonObject ?: JsonObject(emptyMap())).toMutableMap().apply {
            put("announcement", json.encodeToJsonElement(Announcement.serializer(), value.home.announcement))
            put("banner", json.encodeToJsonElement(HomeBanner.serializer(), value.home.banner))
            put("sectionBanner", json.encodeToJsonElement(SectionBanner.serializer(), value.home.sectionBanner))
        }
        val payload = original.toMutableMap().apply {
            put("websiteHome", JsonObject(home))
            put("websiteSocial", json.encodeToJsonElement(WebsiteSocial.serializer(), value.social))
            put("wholesale", json.encodeToJsonElement(WholesaleSettings.serializer(), value.wholesale))
            put("shippingPricing", json.encodeToJsonElement(ShippingPricing.serializer(), value.shippingPricing))
        }
        api().saveMarketingConfig(JsonObject(payload))
    }

    fun productPayload(
        id: String,
        name: String,
        productCode: String,
        category: String,
        description: String,
        price: Double,
        oldPrice: Double,
        purchasePrice: Double,
        commissionPercent: Double,
        images: List<String>,
        sizeType: String,
        sizeQuantities: Map<String, Int>,
        colors: List<String>,
        isHidden: Boolean,
        wholesaleEnabled: Boolean = false,
        wholesalePrice: Double = 0.0,
        wholesaleMinQty: Int = 0,
    ): JsonObject {
        val fields = mutableMapOf<String, JsonElement>(
            "name" to JsonPrimitive(name),
            "productCode" to JsonPrimitive(productCode),
            "category" to JsonPrimitive(category),
            "description" to JsonPrimitive(description),
            "price" to JsonPrimitive(price),
            "oldPrice" to JsonPrimitive(oldPrice),
            "purchasePrice" to JsonPrimitive(purchasePrice),
            "commissionPercent" to JsonPrimitive(commissionPercent),
            "imageUrl" to JsonPrimitive(images.firstOrNull().orEmpty()),
            "imageUrls" to JsonArray(images.map { JsonPrimitive(it) }),
            "sizeType" to JsonPrimitive(sizeType),
            "sizes" to JsonArray(sizeQuantities.keys.map { JsonPrimitive(it) }),
            "colors" to JsonArray(colors.map { JsonPrimitive(it) }),
            "sizeQuantities" to JsonObject(sizeQuantities.mapValues { JsonPrimitive(it.value) }),
            "isHidden" to JsonPrimitive(if (isHidden) 1 else 0),
            "wholesaleEnabled" to JsonPrimitive(if (wholesaleEnabled) 1 else 0),
            "wholesalePrice" to JsonPrimitive(wholesalePrice),
            "wholesaleMinQty" to JsonPrimitive(wholesaleMinQty),
        )
        if (id.isNotBlank()) fields["id"] = JsonPrimitive(id)
        return JsonObject(fields)
    }
}
