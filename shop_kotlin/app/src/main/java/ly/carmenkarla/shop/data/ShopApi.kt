package ly.carmenkarla.shop.data

import kotlinx.serialization.json.JsonObject
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Path
import retrofit2.http.Query

interface ShopApi {

    @GET("products")
    suspend fun products(): ProductsResponse

    @GET("delivery/darb-sabeel/destinations")
    suspend fun destinations(): DestinationsResponse

    @GET("delivery/darb-sabeel/shipping-cost")
    suspend fun shippingCost(
        @Query("city") city: String,
        @Query("area") area: String = "",
        @Query("address") address: String = "",
    ): ShippingQuoteResponse

    @GET("app/content")
    suspend fun appContent(): AppContent

    @POST("presence/ping")
    suspend fun presencePing(@Body body: JsonObject): SimpleResponse

    @POST("orders")
    suspend fun submitOrder(
        @Body body: JsonObject,
        @Header("Authorization") authorization: String?,
    ): OrderResponse

    @GET("orders/{id}/tracking")
    suspend fun tracking(@Path("id") id: String, @Query("token") token: String): TrackingResponse

    @GET("customers/me/orders")
    suspend fun accountOrders(@Header("Authorization") authorization: String): AccountOrdersResponse

    @GET("ambassadors/me/profile")
    suspend fun ambassadorProfile(@Header("Authorization") authorization: String): AmbassadorProfileResponse

    @PUT("ambassadors/me/profile")
    suspend fun saveAmbassadorProfile(
        @Header("Authorization") authorization: String,
        @Body body: JsonObject,
    ): AmbassadorProfileResponse

    @GET("ambassadors/me/orders")
    suspend fun ambassadorOrders(
        @Header("Authorization") authorization: String,
        @Query("limit") limit: Int = 300,
    ): AmbassadorOrdersResponse

    @POST("ambassadors/me/orders/{id}/cancel")
    suspend fun cancelAmbassadorOrder(
        @Path("id") id: String,
        @Header("Authorization") authorization: String,
    ): SimpleResponse

    @GET("ambassadors/me/withdrawals")
    suspend fun ambassadorWithdrawals(@Header("Authorization") authorization: String): WithdrawalSummary

    @POST("ambassadors/me/withdrawals")
    suspend fun requestWithdrawal(@Header("Authorization") authorization: String): WithdrawalSummary

    @POST("ambassadors/me/share-token")
    suspend fun ambassadorShareToken(@Header("Authorization") authorization: String): AmbassadorShare
}
