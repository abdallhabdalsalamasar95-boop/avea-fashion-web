package ly.carmenkarla.shop.notify

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.data.OrderStatusLabels
import java.util.concurrent.TimeUnit

/** Polls tracking for saved orders; used because FCM needs a Firebase console registration. */
class OrderStatusWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val app = runCatching { ShopApp.instance }.getOrNull() ?: return Result.success()
        app.syncOrderStatuses()
        return Result.success()
    }

    companion object {
        private const val NAME = "order-status-sync"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<OrderStatusWorker>(3, TimeUnit.HOURS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                )
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        fun messageFor(status: String): String = when (status) {
            "processing" -> "تم قبول طلبك وجارٍ تجهيزه للشحن."
            "shipped" -> "طلبك قيد التوصيل — استعدي لاستلامه."
            "delivered" -> "تم توصيل طلبك بنجاح. نتمنى يعجبك!"
            "postponed" -> "تم تأجيل توصيل طلبك، سنتواصل معك."
            "returning" -> "طلبك في طريق الإرجاع."
            "returned" -> "تم إرجاع طلبك."
            "canceled" -> "تم إلغاء طلبك. تواصلي معنا لو تحتاجين مساعدة."
            else -> OrderStatusLabels.of(status)
        }
    }
}
