package ly.carmenkarla.shop.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.dataStore by preferencesDataStore("carmen_shop")

private val CART = stringPreferencesKey("cart")
private val FAVORITES = stringPreferencesKey("favorites")
private val CUSTOMER = stringPreferencesKey("customer")
private val ORDERS = stringPreferencesKey("orders")
private val AMBASSADOR_REFERRAL = stringPreferencesKey("ambassador_referral")
private val DESTINATIONS = stringPreferencesKey("delivery_destinations")

/** Keeps the cart, favourites, saved address and placed orders across app restarts. */
class ShopStore(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    suspend fun loadCart(): List<CartLine> = read(CART) {
        json.decodeFromString<List<CartLine>>(it)
    } ?: emptyList()

    suspend fun saveCart(lines: List<CartLine>) = write(CART, json.encodeToString(lines))

    suspend fun loadFavorites(): Set<String> = read(FAVORITES) {
        json.decodeFromString<Set<String>>(it)
    } ?: emptySet()

    suspend fun saveFavorites(ids: Set<String>) = write(FAVORITES, json.encodeToString(ids))

    suspend fun loadCustomer(): CustomerDetails = read(CUSTOMER) {
        json.decodeFromString<CustomerDetails>(it)
    } ?: CustomerDetails()

    suspend fun saveCustomer(value: CustomerDetails) = write(CUSTOMER, json.encodeToString(value))

    suspend fun loadOrders(): List<SavedOrder> = read(ORDERS) {
        json.decodeFromString<List<SavedOrder>>(it)
    } ?: emptyList()

    suspend fun saveOrders(orders: List<SavedOrder>) = write(ORDERS, json.encodeToString(orders))

    suspend fun loadAmbassadorReferral(): String = read(AMBASSADOR_REFERRAL) { it } ?: ""

    suspend fun saveAmbassadorReferral(token: String) = write(AMBASSADOR_REFERRAL, token)

    suspend fun loadDestinations(): Map<String, List<String>> = read(DESTINATIONS) {
        json.decodeFromString<Map<String, List<String>>>(it)
    } ?: emptyMap()

    suspend fun saveDestinations(value: Map<String, List<String>>) =
        write(DESTINATIONS, json.encodeToString(value))

    private suspend fun <T> read(key: androidx.datastore.preferences.core.Preferences.Key<String>, parse: (String) -> T): T? {
        val raw = context.dataStore.data.first()[key] ?: return null
        return runCatching { parse(raw) }.getOrNull()
    }

    private suspend fun write(key: androidx.datastore.preferences.core.Preferences.Key<String>, value: String) {
        context.dataStore.edit { it[key] = value }
    }
}
