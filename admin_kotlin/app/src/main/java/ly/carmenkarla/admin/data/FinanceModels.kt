package ly.carmenkarla.admin.data

import kotlinx.serialization.Serializable

@Serializable
data class OrderCommission(
    val state: String = "",
    val status: String = "pending",
    val baseAmount: Double = 0.0,
    val approvedAmount: Double = 0.0,
    val note: String = "",
)

@Serializable
data class AmbassadorCommissionHistoryEntry(
    val id: String = "",
    val action: String = "",
    val previousStatus: String = "",
    val nextStatus: String = "",
    val previousAmount: Double = 0.0,
    val nextAmount: Double = 0.0,
    val delta: Double = 0.0,
    val note: String = "",
    val createdAtMs: Long = 0,
    val actor: String = "",
)

@Serializable
data class AmbassadorCommissionRecord(
    val id: String = "",
    val sourceType: String = "manual",
    val orderId: String = "",
    val ambassadorKey: String = "",
    val ambassadorUid: String = "",
    val ambassadorName: String = "",
    val ambassadorEmail: String = "",
    val ambassadorPhone: String = "",
    val status: String = "pending",
    val baseAmount: Double = 0.0,
    val approvedAmount: Double = 0.0,
    val note: String = "",
    val reason: String = "",
    val createdAtMs: Long = 0,
    val updatedAtMs: Long = 0,
    val history: List<AmbassadorCommissionHistoryEntry> = emptyList(),
) {
    val isApproved: Boolean get() = status == "approved"
    val isPending: Boolean get() = status == "pending"
    val isCanceled: Boolean get() = status == "canceled"
}

@Serializable
data class AmbassadorFinanceEvent(
    val id: String = "",
    val type: String = "",
    val label: String = "",
    val amount: Double = 0.0,
    val status: String = "",
    val createdAtMs: Long = 0,
    val note: String = "",
    val orderId: String = "",
)

@Serializable
data class AmbassadorFinanceProfile(
    val key: String = "",
    val uid: String = "",
    val name: String = "مندوبة غير محددة",
    val email: String = "",
    val phone: String = "",
    val address: String = "",
    val status: String = "active",
    val joinedAtMs: Long = 0,
    val lastOrderMs: Long = 0,
    val ordersCount: Int = 0,
    val deliveredOrders: Int = 0,
    val openOrders: Int = 0,
    val canceledOrders: Int = 0,
    val pieces: Int = 0,
    val sales: Double = 0.0,
    val pipelineCommission: Double = 0.0,
    val pendingApprovalCommission: Double = 0.0,
    val approvedCommission: Double = 0.0,
    val canceledCommission: Double = 0.0,
    val manualAdjustments: Double = 0.0,
    val approvedAdjustments: Double = 0.0,
    val pendingAdjustments: Double = 0.0,
    val reservedWithdrawals: Double = 0.0,
    val pendingWithdrawalsTotal: Double = 0.0,
    val approvedWithdrawalsTotal: Double = 0.0,
    val paidWithdrawalsTotal: Double = 0.0,
    val rejectedWithdrawalsTotal: Double = 0.0,
    val availableBalance: Double = 0.0,
    val needsAttention: Boolean = false,
    val orders: List<Order> = emptyList(),
    val records: List<AmbassadorCommissionRecord> = emptyList(),
    val history: List<AmbassadorFinanceEvent> = emptyList(),
) {
    val displayName: String get() = name.ifBlank { "مندوبة" }
    val deliveryRate: Int get() = if (ordersCount == 0) 0 else ((deliveredOrders * 100.0) / ordersCount).toInt()
    val averageOrder: Double get() = if (ordersCount == 0) 0.0 else sales / ordersCount
}

@Serializable
data class AmbassadorProgramSummaryTotals(
    val ambassadorCount: Int = 0,
    val ordersCount: Int = 0,
    val sales: Double = 0.0,
    val pipelineCommission: Double = 0.0,
    val pendingApprovalCommission: Double = 0.0,
    val approvedCommission: Double = 0.0,
    val canceledCommission: Double = 0.0,
    val manualAdjustments: Double = 0.0,
    val availableBalance: Double = 0.0,
    val reservedWithdrawals: Double = 0.0,
    val pendingWithdrawalsTotal: Double = 0.0,
    val approvedWithdrawalsTotal: Double = 0.0,
    val paidWithdrawalsTotal: Double = 0.0,
    val deliveredOrders: Int = 0,
    val openOrders: Int = 0,
)

@Serializable
data class AmbassadorFinanceSummaryResponse(
    val ok: Boolean = true,
    val count: Int = 0,
    val items: List<AmbassadorFinanceProfile> = emptyList(),
    val summary: AmbassadorProgramSummaryTotals = AmbassadorProgramSummaryTotals(),
    val source: String = "",
    val warning: String = "",
)

@Serializable
data class AmbassadorFinanceDetailResponse(
    val ok: Boolean = true,
    val item: AmbassadorFinanceProfile = AmbassadorFinanceProfile(),
    val source: String = "",
    val warning: String = "",
)

@Serializable
data class CommissionActionResponse(
    val ok: Boolean = false,
    val error: String = "",
    val item: AmbassadorCommissionRecord = AmbassadorCommissionRecord(),
)
