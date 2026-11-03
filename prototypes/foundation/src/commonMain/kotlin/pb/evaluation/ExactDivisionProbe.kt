package pb.evaluation

import com.ionspin.kotlin.bignum.decimal.BigDecimal
import com.ionspin.kotlin.bignum.integer.BigInteger

/** Bounded evaluation adapter, not the product PB numeric policy.
 * Reuses the library's integers and decimal parser; does not use its decimal divide.
 * q = floor(scaled numerator / denominator), then compare 2 * remainder to denominator.
 */
object ExactDivisionProbe {
    enum class Rounding { HALF_UP, HALF_EVEN, DOWN }

    fun divide(left: String, right: String, precision: Int = 12, rounding: Rounding = Rounding.HALF_UP): BigDecimal {
        require(precision in 1..100)
        // Bound input before parsing and powers before allocation. These are probe limits, not PB limits.
        require(left.length <= 300 && right.length <= 300)
        val a = DecimalProbe.parse(left)
        val b = DecimalProbe.parse(right)
        require(a.precision <= 256 && b.precision <= 256)
        require(a.exponent in -1000L..1000L && b.exponent in -1000L..1000L)
        if (b.significand == BigInteger.ZERO) throw ArithmeticException("Division by zero")
        if (a.significand == BigInteger.ZERO) return DecimalProbe.parse("0")
        val negative = (a.significand < BigInteger.ZERO) != (b.significand < BigInteger.ZERO)
        val numerator = a.significand.abs()
        val denominator = b.significand.abs()
        val digitsA = numerator.numberOfDecimalDigits()
        val digitsB = denominator.numberOfDecimalDigits()
        val difference = digitsA - digitsB
        // floor(log10(numerator / denominator)) without floating point.
        val atLeastPower = if (difference >= 0) numerator >= denominator * BigInteger.TEN.pow(difference)
            else numerator * BigInteger.TEN.pow(-difference) >= denominator
        val ratioExponent = difference - if (atLeastPower) 0 else 1
        val shift = precision - 1L - ratioExponent
        val scaledNumerator = if (shift >= 0) numerator * BigInteger.TEN.pow(shift) else numerator
        val scaledDenominator = if (shift < 0) denominator * BigInteger.TEN.pow(-shift) else denominator
        val (quotient, remainder) = scaledNumerator.divrem(scaledDenominator)
        val comparison = (remainder * BigInteger.fromInt(2)).compareTo(scaledDenominator)
        val increment = when (rounding) {
            Rounding.DOWN -> false
            Rounding.HALF_UP -> comparison >= 0
            Rounding.HALF_EVEN -> comparison > 0 || (comparison == 0 && quotient % BigInteger.fromInt(2) != BigInteger.ZERO)
        }
        val rounded = if (increment) quotient + BigInteger.ONE else quotient
        val exponentOffset = (a.exponent - digitsA + 1) - (b.exponent - digitsB + 1)
        return DecimalProbe.parse("${if (negative) "-" else ""}${rounded}E${exponentOffset - shift}")
    }
}
