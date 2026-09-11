package ly.carmenkarla.shop

import android.app.Application
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import ly.carmenkarla.shop.data.AmbassadorProfile
import ly.carmenkarla.shop.data.CartLine
import ly.carmenkarla.shop.data.CommissionConfig
import ly.carmenkarla.shop.data.CustomerDetails
import ly.carmenkarla.shop.data.OrderStatusLabels
import ly.carmenkarla.shop.data.SavedOrder
import ly.carmenkarla.shop.data.SharedCartSelection
import ly.carmenkarla.shop.data.ShopRepository
import ly.carmenkarla.shop.data.ShopStore
import ly.carmenkarla.shop.data.SupportContact
import ly.carmenkarla.shop.data.WholesaleSettings
import ly.carmenkarla.shop.notify.OrderNotifier
import ly.carmenkarla.shop.notify.OrderStatusWorker

private const val BACKEND_URL = "https://carmenkarla-backend.onrender.com/"

/** Outcome of an add-to-cart attempt once warehouse stock is taken into account. */
sealed interface CartAddResult {
    data object Added : CartAddResult
    /** Only [available] pieces were left, so the cart was topped up to that amount. */
    data class Capped(val available: Int) : CartAddResult
    data class OutOfStock(val available: Int) : CartAddResult
}

class ShopApp : Application() {

    lateinit var repository: ShopRepository
        private set
    lateinit var account: ly.carmenkarla.shop.data.AccountService
        private set
    private lateinit var store: ShopStore
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val cart: SnapshotStateList<CartLine> = mutableStateListOf()
    val favorites: SnapshotStateList<String> = mutableStateListOf()
    val orders: SnapshotStateList<SavedOrder> = mutableStateListOf()
    var customer = mutableStateOf(CustomerDetails())

    /** Non-null while the signed-in user is an approved ambassador. */
    var ambassador by mutableStateOf<AmbassadorProfile?>(null)

    /** Ambassadors can shop for themselves; only ordering "as ambassador" earns commission. */
    var ambassadorMode by mutableStateOf(true)

    /** Referral token captured from storefront shared links (web deep links). */
    var sharedAmbassadorToken by mutableStateOf("")
        private set

    val activeAmbassador: AmbassadorProfile?
        get() = ambassador?.takeIf { ambassadorMode }

    /** Commission rules published by the admin panel. */
    var commission by mutableStateOf(CommissionConfig())
        private set

    /** Wholesale section settings published by the admin panel. */
    var wholesale by mutableStateOf(WholesaleSettings())
        private set

    /** WhatsApp support contact published by the admin panel. */
    var support by mutableStateOf(SupportContact())
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        repository = ShopRepository(BACKEND_URL)
        account = ly.carmenkarla.shop.data.AccountService(this)
        store = ShopStore(this)

        scope.launch {
            cart.addAll(store.loadCart())
            favorites.addAll(store.loadFavorites())
            orders.addAll(store.loadOrders())
            sharedAmbassadorToken = store.loadAmbassadorReferral()
            customer.value = store.loadCustomer()
            // Load cached delivery destinations first; replace them with the
            // provider list when the network is available.
            val cachedDestinations = store.loadDestinations()
            if (cachedDestinations.isNotEmpty()) deliveryDestinations = cachedDestinations
            val content = repository.appContent()
            commission = content.commission
            support = content.ambassadorSupport
            wholesale = content.wholesale
            refreshAmbassador()
        }

        OrderNotifier.ensureChannel(this)
        OrderStatusWorker.schedule(this)
    }

    var deliveryDestinations by mutableStateOf<Map<String, List<String>>>(emptyMap())

    suspend fun refreshDeliveryDestinations() {
        runCatching { repository.destinations() }
            .onSuccess { if (it.isNotEmpty()) { deliveryDestinations = it; store.saveDestinations(it) } }
    }

    /** Puts every line of a past order back in the cart; returns how many were added. */
    fun reorder(order: SavedOrder): Int {
        var added = 0
        order.items.forEachIndexed { index, line ->
            if (line.productId.isBlank()) return@forEachIndexed
            addToCart(
                CartLine(
                    lineId = "${line.productId}_${line.size}_${line.color}_$index",
                    productId = line.productId,
                    productCode = line.productCode,
                    name = line.name,
                    price = line.price,
                    imageUrl = line.imageUrl,
                    size = line.size,
                    color = line.color,
                    quantity = line.quantity.coerceAtLeast(1),
                ),
            )
            added++
        }
        return added
    }

    suspend fun refreshAmbassador() {
        val token = account.idToken()
        ambassador = if (token.isBlank()) null
        else runCatching { repository.ambassadorProfile(token) }.getOrNull()
    }

    fun rememberSharedAmbassadorToken(token: String) {
        val normalized = token.trim()
        sharedAmbassadorToken = normalized
        scope.launch { store.saveAmbassadorReferral(normalized) }
    }

    fun clearSharedAmbassadorToken() {
        sharedAmbassadorToken = ""
        scope.launch { store.saveAmbassadorReferral("") }
    }

    /** Bumped after an external sign-in so screens re-read the auth state. */
    var accountRevision by mutableStateOf(0)

    /** Random per-launch id so a shopper is counted once per session. */
    private val presenceSessionId: String = java.util.UUID.randomUUID().toString()

    /** Cleared by the server when the admin turns live-visitor tracking off. */
    var presenceEnabled by mutableStateOf(true)
        private set

    fun pingPresence(screen: String = "") {
        if (!presenceEnabled) return
        scope.launch {
            presenceEnabled = repository.presencePing(
                sessionId = presenceSessionId,
                uid = account.user?.uid.orEmpty(),
                name = customer.value.name.ifBlank { account.displayName },
                city = customer.value.city,
                screen = screen,
            )
        }
    }

    /** Fills the cart from a `?cart=` payload produced by the storefront share link. */
    suspend fun applySharedCart(encoded: String): Boolean {
        if (encoded.isBlank()) return false
        val selections = runCatching {
            val json = String(
                android.util.Base64.decode(encoded, android.util.Base64.URL_SAFE),
                Charsets.UTF_8,
            )
            Json { ignoreUnknownKeys = true }.decodeFromString<List<SharedCartSelection>>(json)
        }.getOrNull().orEmpty()
        if (selections.isEmpty()) return false

        val catalog = runCatching { repository.products() }.getOrNull().orEmpty().associateBy { it.id }
        var added = false
        selections.forEach { selection ->
            val product = catalog[selection.productId] ?: return@forEach
            addToCart(
                CartLine(
                    lineId = "${product.id}_${selection.size}_${selection.color}",
                    productId = product.id,
                    productCode = product.productCode,
                    name = product.name,
                    price = product.price,
                    imageUrl = product.gallery.firstOrNull().orEmpty(),
                    size = selection.size,
                    color = selection.color,
                    quantity = selection.quantity.coerceIn(1, 99),
                ),
            )
            added = true
        }
        return added
    }

    private fun persistCart() {
        scope.launch { store.saveCart(cart.toList()) }
    }

    fun addToCart(line: CartLine): CartAddResult {
        val index = cart.indexOfFirst { it.lineId == line.lineId }
        val current = if (index >= 0) cart[index].quantity else 0
        val limit = line.stockLimit
        if (limit in 1..current) return CartAddResult.OutOfStock(limit)
        val wanted = current + line.quantity
        val target = if (limit > 0) minOf(wanted, limit) else wanted
        if (index >= 0) {
            cart[index] = cart[index].copy(quantity = target, stockLimit = limit)
        } else {
            cart.add(line.copy(quantity = target))
        }
        persistCart()
        return if (target < wanted) CartAddResult.Capped(target) else CartAddResult.Added
    }

    fun setQuantity(lineId: String, quantity: Int) {
        val index = cart.indexOfFirst { it.lineId == lineId }
        if (index < 0) return
        val existing = cart[index]
        val limit = existing.stockLimit
        val capped = if (limit > 0) quantity.coerceAtMost(limit) else quantity
        if (capped <= 0) cart.removeAt(index) else cart[index] = existing.copy(quantity = capped)
        persistCart()
    }

    fun removeLine(lineId: String) {
        cart.removeAll { it.lineId == lineId }
        persistCart()
    }

    fun clearCart() {
        cart.clear()
        persistCart()
    }

    fun isFavorite(productId: String) = favorites.contains(productId)

    fun toggleFavorite(productId: String) {
        if (!favorites.remove(productId)) favorites.add(productId)
        scope.launch { store.saveFavorites(favorites.toSet()) }
    }

    fun clearFavorites() {
        favorites.clear()
        scope.launch { store.saveFavorites(emptySet()) }
    }

    /** Wipes local traces after the Firebase account itself has been removed. */
    fun clearAfterAccountDeletion() {
        ambassador = null
        favorites.clear()
        cart.clear()
        orders.clear()
        customer.value = CustomerDetails()
        accountRevision++
        scope.launch {
            store.saveFavorites(emptySet())
            store.saveCart(emptyList())
            store.saveOrders(emptyList())
            store.saveCustomer(CustomerDetails())
        }
    }

    fun rememberCustomer(value: CustomerDetails) {
        customer.value = value
        scope.launch { store.saveCustomer(value) }
    }

    fun rememberOrder(order: SavedOrder) {
        orders.add(0, order)
        scope.launch { store.saveOrders(orders.toList()) }
    }

    /** Checks every saved order's live status and notifies once per change. */
    suspend fun syncOrderStatuses() {
        var changed = false
        orders.toList().forEachIndexed { index, order ->
            if (order.trackingToken.isBlank()) return@forEachIndexed
            val live = runCatching {
                repository.tracking(order.orderId, order.trackingToken)
            }.getOrNull() ?: return@forEachIndexed

            val status = live.status.ifBlank { "pending" }
            if (status == order.notifiedStatus) return@forEachIndexed

            OrderNotifier.notifyStatus(
                this,
                order.orderId,
                "طلب #${order.orderId.takeLast(6)} · ${OrderStatusLabels.of(status)}",
                OrderStatusWorker.messageFor(status),
            )
            if (index < orders.size) {
                orders[index] = orders[index].copy(notifiedStatus = status)
                changed = true
            }
        }
        if (changed) store.saveOrders(orders.toList())
    }

    val cartCount: Int get() = cart.sumOf { it.quantity }
    val cartSubtotal: Double get() = cart.sumOf { it.lineTotal }

    companion object {
        lateinit var instance: ShopApp
            private set
    }
}
