package pb.evaluation
import kotlin.test.Test
import kotlin.test.assertEquals

class GuardedDivisionDiagnosticTest {
    @Test fun knownDivisionCasesWithExtraPrecision() {
        for ((a, b, expected) in listOf(
            Triple("2", "3", "0.666666666667"),
            Triple("-241365E-45", "377629E-66", "-6.39159068822E20")
        )) {
            assertEquals(0, DecimalProbe.guardedDivision(a, b).compareTo(DecimalProbe.parse(expected)))
        }
    }
}
