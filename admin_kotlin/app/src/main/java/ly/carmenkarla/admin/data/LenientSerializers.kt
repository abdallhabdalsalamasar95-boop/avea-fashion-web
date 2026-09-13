package ly.carmenkarla.admin.data

import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/**
 * The catalog is stored as loose JSON, so a field can arrive as an array, a comma
 * separated string, or an empty string. These serializers accept all three shapes.
 */

private fun splitLoose(raw: String): List<String> =
    raw.split(',', '،', '|').map { it.trim() }.filter { it.isNotEmpty() }

object LenientStringList : KSerializer<List<String>> {
    private val delegate = ListSerializer(String.serializer())
    override val descriptor: SerialDescriptor = delegate.descriptor

    override fun deserialize(decoder: Decoder): List<String> {
        val input = decoder as? JsonDecoder ?: return emptyList()
        return when (val element = input.decodeJsonElement()) {
            is JsonArray -> element.mapNotNull { (it as? JsonPrimitive)?.contentOrNull?.trim() }
                .filter { it.isNotEmpty() }
            is JsonPrimitive -> splitLoose(element.contentOrNull.orEmpty())
            else -> emptyList()
        }
    }

    override fun serialize(encoder: Encoder, value: List<String>) = delegate.serialize(encoder, value)
}

object LenientIntMap : KSerializer<Map<String, Int>> {
    private val delegate = MapSerializer(String.serializer(), Int.serializer())
    override val descriptor: SerialDescriptor = delegate.descriptor

    override fun deserialize(decoder: Decoder): Map<String, Int> {
        val input = decoder as? JsonDecoder ?: return emptyMap()
        val element = input.decodeJsonElement() as? JsonObject ?: return emptyMap()
        return element.mapNotNull { (key, raw) ->
            val number = (raw as? JsonPrimitive)?.contentOrNull?.toDoubleOrNull() ?: return@mapNotNull null
            key to number.toInt()
        }.toMap()
    }

    override fun serialize(encoder: Encoder, value: Map<String, Int>) = delegate.serialize(encoder, value)
}

object LenientDouble : KSerializer<Double> {
    override val descriptor: SerialDescriptor = Double.serializer().descriptor

    override fun deserialize(decoder: Decoder): Double {
        val input = decoder as? JsonDecoder ?: return 0.0
        val primitive = input.decodeJsonElement() as? JsonPrimitive ?: return 0.0
        return primitive.contentOrNull?.toDoubleOrNull() ?: 0.0
    }

    override fun serialize(encoder: Encoder, value: Double) = encoder.encodeDouble(value)
}

object LenientInt : KSerializer<Int> {
    override val descriptor: SerialDescriptor = Int.serializer().descriptor

    override fun deserialize(decoder: Decoder): Int {
        val input = decoder as? JsonDecoder ?: return 0
        val primitive = input.decodeJsonElement() as? JsonPrimitive ?: return 0
        return primitive.contentOrNull?.toDoubleOrNull()?.toInt() ?: 0
    }

    override fun serialize(encoder: Encoder, value: Int) = encoder.encodeInt(value)
}
