package ly.carmenkarla.admin.data

/** Size presets per product type, matching the four sizeType values the backend accepts. */
object SizeCatalog {

    val types = listOf(
        "clothing" to "ملابس",
        "abaya" to "عبايات",
        "shoes" to "أحذية",
        "oneSize" to "مقاس واحد",
    )

    private val clothing = listOf("36", "38", "40", "42", "44", "46", "48", "50", "52", "54")
    private val abaya = listOf("52", "54", "56", "58", "60", "62")
    private val shoes = listOf("36", "37", "38", "39", "40", "41", "42", "43")
    private val oneSize = listOf("مقاس واحد")

    fun sizesFor(type: String): List<String> = when (type) {
        "abaya" -> abaya
        "shoes" -> shoes
        "oneSize" -> oneSize
        else -> clothing
    }

    fun label(type: String): String = types.firstOrNull { it.first == type }?.second ?: type
}

/** Colours offered as chips; the editor still allows typing a custom one. */
val COMMON_COLORS = listOf(
    "أسود", "أبيض", "أحمر", "كحلي", "أزرق", "أخضر",
    "بيج", "بني", "وردي", "بنفسجي", "رمادي", "ذهبي", "فضي",
)
