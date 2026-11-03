package pb.evaluation

import com.ionspin.kotlin.bignum.decimal.BigDecimal
import com.ionspin.kotlin.bignum.decimal.DecimalMode
import com.ionspin.kotlin.bignum.decimal.RoundingMode

/** Evaluation model only: twelve significant digits, half away from zero.
 * This is not a confirmed PB-100 rounding policy. Operands are parsed exactly.
 */
object DecimalProbe {
    val mode = DecimalMode(12, RoundingMode.ROUND_HALF_AWAY_FROM_ZERO)
    /** Diagnostic only: extra precision is not a proven general division fix. */
    fun guardedDivision(left: String, right: String): BigDecimal =
        parse(left).divide(parse(right), DecimalMode(24, RoundingMode.ROUND_HALF_AWAY_FROM_ZERO))
            .roundSignificand(mode)
    fun parse(text: String): BigDecimal = BigDecimal.parseString(text)
    fun calculate(op: String, left: String, right: String): BigDecimal {
        val a = parse(left)
        val b = parse(right)
        return when (op) {
            "+" -> a.add(b, mode)
            "-" -> a.subtract(b, mode)
            "*" -> a.multiply(b, mode)
            "/" -> a.divide(b, mode)
            else -> error("Unknown evaluation operation: $op")
        }
    }
}
