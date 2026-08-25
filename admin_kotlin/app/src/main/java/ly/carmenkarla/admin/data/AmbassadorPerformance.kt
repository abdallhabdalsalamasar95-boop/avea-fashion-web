package ly.carmenkarla.admin.data

/** Per-ambassador figures derived from orders, since the backend exposes them only per order. */
data class AmbassadorPerformance(
    val ambassador: Ambassador,
    val totalOrders: Int = 0,
    val deliveredOrders: Int = 0,
    val returnedOrders: Int = 0,
    val canceledOrders: Int = 0,
    val activeOrders: Int = 0,
    val totalSales: Double = 0.0,
    val deliveredSales: Double = 0.0,
    val earnedCommission: Double = 0.0,
    val pendingCommission: Double = 0.0,
    val paidOut: Double = 0.0,
    val pendingWithdrawals: Double = 0.0,
    val recentOrders: List<Order> = emptyList(),
) {
    val successRate: Int
        get() = if (totalOrders == 0) 0 else (deliveredOrders * 100) / totalOrders
}

private val RETURN_STATUSES = setOf("returning", "returned")
private val CLOSED_STATUSES = setOf("canceled") + RETURN_STATUSES

fun buildAmbassadorPerformance(
    people: List<Ambassador>,
    orders: List<Order>,
    withdrawals: List<Withdrawal>,
): List<AmbassadorPerformance> {
    val ordersByName = orders
        .filter { it.ambassadorSummary.isAmbassadorOrder }
        .groupBy { it.ambassadorSummary.ambassadorName.trim() }

    return people.map { person ->
        val mine = ordersByName[person.ambassadorName.trim()].orEmpty()
        val myWithdrawals = withdrawals.filter {
            it.ambassadorUid == person.uid || it.ambassadorName.trim() == person.ambassadorName.trim()
        }
        val delivered = mine.filter { it.status == "delivered" }
        val active = mine.filter { it.status !in CLOSED_STATUSES && it.status != "delivered" }

        AmbassadorPerformance(
            ambassador = person,
            totalOrders = mine.size,
            deliveredOrders = delivered.size,
            returnedOrders = mine.count { it.status in RETURN_STATUSES },
            canceledOrders = mine.count { it.status in CLOSED_STATUSES },
            activeOrders = active.size,
            totalSales = mine.sumOf { it.grandTotal },
            deliveredSales = delivered.sumOf { it.grandTotal },
            earnedCommission = delivered.sumOf { it.ambassadorSummary.commissionTotal },
            pendingCommission = active.sumOf { it.ambassadorSummary.commissionTotal },
            paidOut = myWithdrawals.filter { it.status == "paid" }.sumOf { it.amount },
            pendingWithdrawals = myWithdrawals.filter { it.status in setOf("pending", "approved") }.sumOf { it.amount },
            recentOrders = mine.sortedByDescending { it.createdAtMs }.take(10),
        )
    }.sortedByDescending { it.deliveredSales }
}
