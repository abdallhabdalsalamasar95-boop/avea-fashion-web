package ly.carmenkarla.admin.notify

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import ly.carmenkarla.admin.MainActivity
import ly.carmenkarla.admin.R

private const val CHANNEL_ID = "withdrawal_requests"

object WithdrawalNotifier {

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "طلبات سحب المندوبات",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "إشعار عند وصول طلب سحب رصيد جديد من مندوبة" }
        context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    fun notifyWithdrawalRequest(context: Context, id: String, ambassadorName: String, amount: Double) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        ensureChannel(context)

        val name = ambassadorName.ifBlank { "مندوبة" }
        val body = "طلبت $name سحب ${"%.2f".format(amount)} د.ل، اضغطي لمراجعة الطلب والموافقة عليه."

        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("طلب سحب جديد")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .build()

        runCatching {
            NotificationManagerCompat.from(context).notify(id.hashCode(), notification)
        }
    }
}
