from pathlib import Path
from decimal import Decimal, localcontext, ROUND_HALF_UP, ROUND_HALF_EVEN, ROUND_DOWN
import random
r=Path(__file__).resolve().parents[1]
rng=random.Random(100)
rows=[]
for i in range(1000):
    def operand(nonzero=False):
        digits=rng.randint(1,30)
        n=rng.randint(1 if nonzero else 0,10**digits-1)
        if rng.choice([True,False]): n=-n
        return f"{n}E{rng.randint(-99,99)}"
    a,b=operand(),operand(True)
    p=rng.choice([1,2,10,12,24])
    expected=[]
    for rounding in [ROUND_HALF_UP,ROUND_HALF_EVEN,ROUND_DOWN]:
        with localcontext() as ctx:
            ctx.prec=p;ctx.rounding=rounding
            expected.append(str(Decimal(a)/Decimal(b)))
    rows.append("|".join([a,b,str(p)]+expected))
s='''package pb.evaluation
import kotlin.test.Test
import kotlin.test.assertEquals

/** Independent Python decimal fixtures; same 3,000 comparisons on JVM and iOS. */
class ExactDivisionVectorsTest {
    @Test fun independentDivisionVectors() {
        val rows = DATA.trim().lines()
        for ((index, row) in rows.withIndex()) {
            val parts = row.split('|')
            for ((offset, rounding) in ExactDivisionProbe.Rounding.entries.withIndex()) {
                val actual = ExactDivisionProbe.divide(parts[0], parts[1], parts[2].toInt(), rounding)
                assertEquals(0, actual.compareTo(DecimalProbe.parse(parts[3+offset])), "case $index $rounding: $row; actual $actual")
            }
        }
    }
    private val DATA = """
'''+"\n".join(rows)+'''
"""
}
'''
(r/'src/commonTest/kotlin/pb/evaluation/ExactDivisionVectorsTest.kt').write_text(s)
