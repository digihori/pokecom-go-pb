package pb.evaluation

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFails
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

class DecimalProbeTest {
    private fun check(op: String, a: String, b: String, expected: String) {
        assertEquals(0, DecimalProbe.calculate(op, a, b).compareTo(DecimalProbe.parse(expected)), "$a $op $b; expected $expected, actual ${DecimalProbe.calculate(op, a, b)}")
    }
    @Test fun exactDecimalArithmetic() {
        check("+", "0.1", "0.2", "0.3")
        check("*", "1.2", "3.4", "4.08")
        check("-", "0.1", "0.3", "-0.2")
        check("/", "1", "8", "0.125")
    }
    @Test fun recurringDecimalWithExplicitModel() {
        check("/", "1", "3", "0.333333333333")
        check("/", "2", "3", "0.666666666667")
        check("/", "1", "7", "0.142857142857")
    }
    @Test fun modelRoundsEachOperation() {
        check("+", "1.234567890125", "0", "1.23456789013")
        check("+", "-1.234567890125", "0", "-1.23456789013")
        val first = DecimalProbe.calculate("+", "1E12", "1")
        assertEquals(0, first.subtract(DecimalProbe.parse("1E12"), DecimalProbe.mode).compareTo(DecimalProbe.parse("0")))
    }
    @Test fun numericEqualityIgnoresScale() {
        for (value in listOf("1", "1.0", "1E0")) assertEquals(0, DecimalProbe.parse(value).compareTo(DecimalProbe.parse("1")))
        assertEquals(0, DecimalProbe.parse("-0").compareTo(DecimalProbe.parse("0")))
    }
    @Test fun exponentAndStringRoundTrip() {
        for (text in listOf("1E-99", "-1E-99", "9.999999999E99", "-9.999999999E99", "0")) {
            val value = DecimalProbe.parse(text)
            val encoded = Json.encodeToString(value.toString())
            val restored = DecimalProbe.parse(Json.decodeFromString<String>(encoded))
            assertEquals(0, value.compareTo(restored))
        }
        // The general-purpose library is not responsible for PB range enforcement.
        assertEquals(0, DecimalProbe.calculate("/", "1E-99", "10").compareTo(DecimalProbe.parse("1E-100")))
    }
    @Test fun divisionByZeroFails() { assertFails { DecimalProbe.calculate("/", "1", "0") } }
}
