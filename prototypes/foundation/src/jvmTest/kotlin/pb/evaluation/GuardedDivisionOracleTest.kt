package pb.evaluation
import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals

class GuardedDivisionOracleTest {
    @Test fun diagnosticDivisionAgainstJavaDecimal() {
        val random = Random(100)
        val context = MathContext(12, RoundingMode.HALF_UP)
        val mismatches = mutableListOf<String>()
        repeat(1000) { index ->
            val a = "${random.nextInt(-999999, 1000000)}E${random.nextInt(-80, 81)}"
            val b = "${random.nextInt(1, 1000000)}E${random.nextInt(-80, 81)}"
            val expected = BigDecimal(a).divide(BigDecimal(b), context)
            val actual = BigDecimal(DecimalProbe.guardedDivision(a, b).toString())
            if (expected.compareTo(actual) != 0) mismatches += "$index: $a / $b; $expected != $actual"
        }
        assertEquals(0, mismatches.size, "${mismatches.size}/1000; ${mismatches.take(10)}")
    }
}
