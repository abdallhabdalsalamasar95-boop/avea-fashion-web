package ly.carmenkarla.shop.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import ly.carmenkarla.shop.ShopApp

/** Falls back to the storefront's published number when the admin panel has none. */
private const val DEFAULT_SUPPORT_NUMBER = "218921397674"

private fun whatsappDigits(raw: String): String {
    var digits = raw.filter { it.isDigit() }
    if (digits.startsWith("00")) digits = digits.drop(2)
    if (digits.startsWith("0")) digits = "218" + digits.drop(1)
    else if (digits.length == 9 && digits.startsWith("9")) digits = "218$digits"
    return if (digits.length in 7..15) digits else ""
}

fun supportNumber(): String =
    whatsappDigits(ShopApp.instance.support.whatsappNumber).ifBlank { DEFAULT_SUPPORT_NUMBER }

fun openSupportChat(context: Context, message: String) {
    val url = "https://wa.me/${supportNumber()}?text=" + Uri.encode(message)
    runCatching {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }
}
