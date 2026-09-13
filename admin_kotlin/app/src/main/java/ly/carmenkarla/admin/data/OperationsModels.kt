package ly.carmenkarla.admin.data

import kotlinx.serialization.Serializable

/** One shipment attempt against Darb Sabeel, stored on the order itself. */
@Serializable
data class ExternalDelivery(
    val provider: String = "",
    val status: String = "",
    val shipmentId: String = "",
    val trackingNumber: String = "",
    val referenceCode: String = "",
    val providerStatus: String = "",
    val lastError: String = "",
)

@Serializable
data class OrderLine(
    val productId: String = "",
    val name: String = "",
    val size: String = "",
    val color: String = "",
    val quantity: Int = 0,
    val price: Double = 0.0,
    val commissionPercent: Double = 0.0,
    val imageUrl: String = "",
)

@Serializable
data class OrderPricing(
    val subtotal: Double = 0.0,
    val discount: Double = 0.0,
    val shippingCost: Double = 0.0,
    val grandTotal: Double = 0.0,
)

@Serializable
data class OrderPayload(
    val items: List<OrderLine> = emptyList(),
    val pricing: OrderPricing = OrderPricing(),
    val note: String = "",
)

@Serializable
data class AmbassadorSummary(
    val isAmbassadorOrder: Boolean = false,
    val ambassadorUid: String = "",
    val ambassadorName: String = "",
    val ambassadorPhone: String = "",
    val ambassadorEmail: String = "",
    val grossSales: Double = 0.0,
    val estimatedCommission: Double = 0.0,
    val commissionPercent: Double = 0.0,
    val commissionTotal: Double = 0.0,
)

@Serializable
data class Order(
    val orderId: String = "",
    val status: String = "pending",
    val createdAtMs: Long = 0,
    val updatedAtMs: Long = 0,
    val customerName: String = "",
    val customerPhone: String = "",
    val customerAddress: String = "",
    val city: String = "",
    val grandTotal: Double = 0.0,
    val itemsCount: Int = 0,
    val source: String = "",
    val payload: OrderPayload = OrderPayload(),
    val ambassadorSummary: AmbassadorSummary = AmbassadorSummary(),
    val commission: OrderCommission = OrderCommission(),
    val externalDelivery: ExternalDelivery = ExternalDelivery(),
    val trackingToken: String = "",
) {
    val deliveryLocationLabel: String
        get() {
            val provider = externalDelivery.providerStatus.lowercase()
            return when (status) {
                "pending" -> "المنتج محجوز للطلب"
                "processing" -> "الطلب قيد التحضير في المخزن"
                "shipped" -> if (provider.contains("assigned") || provider.contains("picked") || provider.contains("courier") || provider.contains("driver")) "الطلب عند المندوب" else "الطلب لدى شركة التوصيل • قيد التوصيل"
                "postponed" -> "مؤجل من شركة التوصيل"
                "delivered" -> "تم تسليم المنتج للزبونة"
                "returning" -> "الطلب راجع مع المندوب"
                "returned" -> "المرتجع وصل إلى المخزن"
                "canceled" -> "الطلب ملغي والمنتج عاد للمخزون"
                else -> if (externalDelivery.status == "created") "الطلب لدى شركة التوصيل" else "لم يُرسل لشركة التوصيل"
            }
        }

    fun fallbackCommission(defaultPercent: Double = 7.0, perProductEnabled: Boolean = true): Double {
        val summary = ambassadorSummary
        val direct = summary.commissionTotal.takeIf { it > 0 }
            ?: summary.estimatedCommission.takeIf { it > 0 }
        if (direct != null) return direct

        val gross = summary.grossSales.takeIf { it > 0 } ?: grandTotal.takeIf { it > 0 } ?: payload.pricing.grandTotal
        val summaryPercent = summary.commissionPercent.takeIf { it > 0 } ?: defaultPercent
        if (summary.grossSales > 0 && summary.commissionPercent > 0) {
            return gross * summaryPercent.coerceIn(0.0, 100.0) / 100.0
        }

        val linesValue = payload.items.sumOf { line ->
            val percent = if (perProductEnabled && line.commissionPercent > 0) line.commissionPercent else summaryPercent
            (line.price * line.quantity) * percent.coerceIn(0.0, 100.0) / 100.0
        }
        if (linesValue > 0) return linesValue

        return gross * summaryPercent.coerceIn(0.0, 100.0) / 100.0
    }
}

@Serializable
data class OrdersResponse(
    val ok: Boolean = true,
    val total: Int = 0,
    val items: List<Order> = emptyList(),
)

@Serializable
data class Customer(
    val phone: String = "",
    val name: String = "",
    val city: String = "",
    val address: String = "",
    val uid: String = "",
    val ordersCount: Int = 0,
    val deliveredCount: Int = 0,
    val canceledCount: Int = 0,
    val openCount: Int = 0,
    val totalSpent: Double = 0.0,
    val firstOrderMs: Long = 0,
    val lastOrderMs: Long = 0,
    val active: Boolean = false,
    val repeat: Boolean = false,
)

@Serializable
data class CustomersResponse(
    val ok: Boolean = true,
    val count: Int = 0,
    val activeCount: Int = 0,
    val repeatCount: Int = 0,
    val items: List<Customer> = emptyList(),
)

@Serializable
data class OrderActionResponse(
    val ok: Boolean = false,
    val error: String = "",
    val item: Order? = null,
)

@Serializable
data class Ambassador(
    val uid: String = "",
    val ambassadorName: String = "",
    val ambassadorPhone: String = "",
    val ambassadorAddress: String = "",
    val email: String = "",
    val status: String = "active",
    val joinedAt: Long = 0,
)

@Serializable
data class AmbassadorsResponse(
    val ok: Boolean = true,
    val count: Int = 0,
    val items: List<Ambassador> = emptyList(),
    val warning: String = "",
)

@Serializable
data class Withdrawal(
    val id: String = "",
    val ambassadorUid: String = "",
    val ambassadorName: String = "",
    val ambassadorPhone: String = "",
    val amount: Double = 0.0,
    val status: String = "pending",
    val createdAtMs: Long = 0,
    val updatedAtMs: Long = 0,
)

@Serializable
data class WithdrawalsResponse(
    val ok: Boolean = true,
    val count: Int = 0,
    val items: List<Withdrawal> = emptyList(),
)

@Serializable
data class Expense(
    val id: String = "",
    val amount: Double = 0.0,
    val category: String = "other",
    val description: String = "",
    val expenseAtMs: Long = 0,
)

@Serializable
data class ExpensesResponse(
    val ok: Boolean = true,
    val count: Int = 0,
    val items: List<Expense> = emptyList(),
)

@Serializable
data class TopProduct(
    val productId: String = "",
    val name: String = "",
    val pieces: Int = 0,
    val sales: Double = 0.0,
    val cost: Double = 0.0,
    val profit: Double = 0.0,
)

@Serializable
data class AccountingSummary(
    val deliveredOrders: Int = 0,
    val soldPieces: Int = 0,
    val revenue: Double = 0.0,
    val costOfGoods: Double = 0.0,
    val grossProfit: Double = 0.0,
    val ambassadorCommissions: Double = 0.0,
    val approvedAmbassadorCommissions: Double = 0.0,
    val pendingAmbassadorCommissions: Double = 0.0,
    val pipelineAmbassadorCommissions: Double = 0.0,
    val availableAmbassadorBalance: Double = 0.0,
    val reservedWithdrawalBalance: Double = 0.0,
    val ambassadorCount: Int = 0,
    val expenses: Double = 0.0,
    val netProfit: Double = 0.0,
    val inventoryPieces: Int = 0,
    val inventoryCostValue: Double = 0.0,
    val inventorySaleValue: Double = 0.0,
    val inventoryPotentialProfit: Double = 0.0,
    val missingCostProducts: Int = 0,
    val missingCostSoldPieces: Int = 0,
    val topProducts: List<TopProduct> = emptyList(),
    val topAmbassadors: List<AmbassadorFinanceProfile> = emptyList(),
)

@Serializable
data class AccountingResponse(
    val ok: Boolean = true,
    val summary: AccountingSummary = AccountingSummary(),
)

/** Arabic labels and ordering for the eight backend order statuses. */
object OrderStatuses {
    val all = listOf(
        "pending" to "قيد الانتظار",
        "processing" to "تم القبول",
        "shipped" to "قيد التوصيل",
        "postponed" to "مؤجل",
        "delivered" to "تم التوصيل",
        "returning" to "قيد الإرجاع",
        "returned" to "مُرجع",
        "canceled" to "ملغي",
    )

    fun label(status: String): String =
        all.firstOrNull { it.first == status }?.second ?: status
}

val EXPENSE_CATEGORIES = listOf(
    "rent" to "إيجار",
    "shipping" to "شحن",
    "marketing" to "تسويق",
    "salary" to "رواتب",
    "utilities" to "فواتير",
    "supplies" to "مستلزمات",
    "other" to "أخرى",
)
