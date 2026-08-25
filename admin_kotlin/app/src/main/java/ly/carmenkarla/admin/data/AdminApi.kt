package ly.carmenkarla.admin.data

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Query

interface AdminApi {

    @GET("products")
    suspend fun products(@Query("includeHidden") includeHidden: String = "1"): ProductsResponse

    @POST("products")
    suspend fun createProduct(@Body body: JsonObject): JsonElement

    @PUT("products/{id}")
    suspend fun updateProduct(@Path("id") id: String, @Body body: JsonObject): JsonElement

    @DELETE("products/{id}")
    suspend fun deleteProduct(@Path("id") id: String): SimpleResponse

    @Multipart
    @POST("products/upload")
    suspend fun uploadImage(@Part image: MultipartBody.Part): UploadResponse

    @GET("dashboard/summary")
    suspend fun dashboard(): DashboardSummary

    @GET("admin/presence")
    suspend fun presence(): PresenceResponse

    @POST("admin/presence/settings")
    suspend fun updatePresenceSettings(@Body body: PresenceSettings): PresenceSettingsResponse

    @GET("marketing/config")
    suspend fun marketingConfig(): JsonObject

    @PUT("marketing/config")
    suspend fun saveMarketingConfig(@Body body: JsonObject): JsonObject

    @GET("orders")
    suspend fun orders(
        @Query("limit") limit: Int = 200,
        @Query("status") status: String = "",
    ): OrdersResponse

    @PUT("orders/{id}/status")
    suspend fun updateOrderStatus(@Path("id") id: String, @Body body: JsonObject): OrderActionResponse

    @POST("admin/orders/external-sale")
    suspend fun createExternalSale(@Body body: JsonObject): OrderActionResponse

    @POST("orders/{id}/delivery/darb-sabeel")
    suspend fun dispatchToDarbSabeel(@Path("id") id: String): OrderActionResponse

    @GET("admin/ambassadors")
    suspend fun ambassadors(): AmbassadorsResponse

    @GET("admin/customers")
    suspend fun customers(@Query("activeDays") activeDays: Int = 60): CustomersResponse

    @GET("admin/ambassador-withdrawals")
    suspend fun withdrawals(): WithdrawalsResponse

    @PUT("admin/ambassador-withdrawals/{id}/status")
    suspend fun updateWithdrawalStatus(@Path("id") id: String, @Body body: JsonObject): SimpleResponse

    @GET("admin/accounting/summary")
    suspend fun accounting(
        @Query("fromMs") fromMs: Long = 0,
        @Query("toMs") toMs: Long = 0,
    ): AccountingResponse

    @GET("admin/expenses")
    suspend fun expenses(): ExpensesResponse

    @POST("admin/expenses")
    suspend fun createExpense(@Body body: JsonObject): SimpleResponse

    @DELETE("admin/expenses/{id}")
    suspend fun deleteExpense(@Path("id") id: String): SimpleResponse
}
