package pb.evaluation

import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals

class CandidateArithmeticOracleTest {
    @Test fun thousandCasesAgainstIndependentJavaDecimal() {
        val random = Random(100)
        val context = MathContext(12, RoundingMode.HALF_UP)
        val mismatches = mutableListOf<String>()
        repeat(1000) { index ->
            val a = "${random.nextInt(-999999, 1000000)}E${random.nextInt(-80, 81)}"
            val b = "${random.nextInt(1, 1000000)}E${random.nextInt(-80, 81)}"
            val op = listOf("+", "-", "*", "/")[index % 4]
            val x = BigDecimal(a); val y = BigDecimal(b)
            val expected = when (op) {
                "+" -> x.add(y, context)
                "-" -> x.subtract(y, context)
                "*" -> x.multiply(y, context)
                else -> x.divide(y, context)
            }
            val actual = BigDecimal(CandidateArithmeticProbe.calculate(op, a, b).toString())
            if (expected.compareTo(actual) != 0) mismatches += "case $index: $a $op $b; expected $expected, actual $actual"
        }
        assertEquals(0, mismatches.size, "${mismatches.size}/1000 mismatches; first examples: ${mismatches.take(10)}")
    }
}
