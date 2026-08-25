package ly.carmenkarla.admin.notify

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import ly.carmenkarla.admin.AdminApp
import java.util.concurrent.TimeUnit

/** Polls pending ambassador withdrawal requests and alerts the admin when a new one arrives. */
class WithdrawalPollWorker(
    private val appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val app = runCatching { AdminApp.instance }.getOrNull() ?: return Result.success()
        val settings = app.repository.settings
        if (settings.currentToken().isEmpty()) return Result.success()

        val withdrawals = runCatching { app.repository.withdrawals() }.getOrNull() ?: return Result.retry()
        val pending = withdrawals.filter { it.status == "pending" }
        if (pending.isEmpty()) return Result.success()

        val alreadyNotified = settings.notifiedWithdrawalIds()
        val fresh = pending.filter { it.id !in alreadyNotified }
        if (fresh.isEmpty()) return Result.success()

        fresh.forEach {
            WithdrawalNotifier.notifyWithdrawalRequest(appContext, it.id, it.ambassadorName, it.amount)
        }
        settings.addNotifiedWithdrawalIds(fresh.map { it.id }.toSet())
        return Result.success()
    }

    companion object {
        private const val NAME = "withdrawal-request-poll"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<WithdrawalPollWorker>(15, TimeUnit.MINUTES)
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
    }
}
