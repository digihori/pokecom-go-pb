package pb.evaluation

/** Candidate composition only: existing decimal +,-,*; exact-remainder division adapter.
 * PB numeric range, error codes, rounding policy and transcendental functions remain undecided.
 */
object CandidateArithmeticProbe {
    fun calculate(op: String, left: String, right: String) = when (op) {
        "/" -> ExactDivisionProbe.divide(left, right)
        else -> DecimalProbe.calculate(op, left, right)
    }
}
