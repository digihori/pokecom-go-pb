package pb.evaluation
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotEquals

class ExactDivisionProbeTest {
    private fun check(a: String, b: String, expected: String, precision: Int = 12,
        rounding: ExactDivisionProbe.Rounding = ExactDivisionProbe.Rounding.HALF_UP) {
        assertEquals(0, ExactDivisionProbe.divide(a, b, precision, rounding).compareTo(DecimalProbe.parse(expected)), "$a / $b ($precision, $rounding)")
    }
    @Test fun knownFailuresAndSigns() {
        check("2", "3", "0.666666666667")
        check("-2", "3", "-0.666666666667")
        check("2", "-3", "-0.666666666667")
        check("-2", "-3", "0.666666666667")
        check("-241365E-45", "377629E-66", "-6.39159068822E20")
        check("1", "8", "0.125")
        check("0", "-3", "0")
        check("1E-99", "10", "1E-100")
    }
    @Test fun tiesCarryAndTruncation() {
        check("1.234567890125", "1", "1.23456789013")
        check("1.234567890125", "1", "1.23456789012", rounding = ExactDivisionProbe.Rounding.HALF_EVEN)
        check("1.234567890135", "1", "1.23456789014", rounding = ExactDivisionProbe.Rounding.HALF_EVEN)
        check("-1.234567890125", "1", "-1.23456789013")
        check("9.999999999995", "1", "10")
        check("-2", "3", "-0.666666666666", rounding = ExactDivisionProbe.Rounding.DOWN)
        check("5", "2", "3", precision = 1)
        check("5", "2", "2", precision = 1, rounding = ExactDivisionProbe.Rounding.HALF_EVEN)
    }
    @Test fun guardDigitsAreNotGeneralFix() {
        val a = "1.2345678901249999999999999"
        val expected = DecimalProbe.parse("1.23456789012")
        assertEquals(0, ExactDivisionProbe.divide(a, "1").compareTo(expected))
        assertNotEquals(0, DecimalProbe.guardedDivision(a, "1").compareTo(expected), "Double rounding counterexample")
    }
    @Test fun boundedInputAndErrors() {
        assertFailsWith<ArithmeticException> { ExactDivisionProbe.divide("1", "0") }
        assertFailsWith<ArithmeticException> { ExactDivisionProbe.divide("0", "0") }
        assertFailsWith<IllegalArgumentException> { ExactDivisionProbe.divide("1", "2", 0) }
        assertFailsWith<IllegalArgumentException> { ExactDivisionProbe.divide("1E1001", "2") }
        assertFailsWith<IllegalArgumentException> { ExactDivisionProbe.divide("1".repeat(301), "2") }
    }
}
