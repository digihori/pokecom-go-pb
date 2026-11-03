from pathlib import Path
from decimal import Decimal, localcontext, ROUND_HALF_UP
r=Path(__file__).resolve().parents[1]
cases=[]
for a,b in [('0.1','0.2'),('1','3'),('-1','7'),('9.99999999999','0.00000000001'),('1E-99','10'),('1E99','3'),('-12.3456789012','2.5'),('999999999999','11'),('0','1'),('1.234567890125','1'),('1E12','1'),('-1E-80','3'),('123456789012','0.003'),('0.000123456789012','7'),('3.14159265359','2')]:
 for op in ['+','-','*','/']:
  with localcontext() as ctx:
   ctx.prec=12;ctx.rounding=ROUND_HALF_UP
   x,y=Decimal(a),Decimal(b)
   v={'+':lambda:x+y,'-':lambda:x-y,'*':lambda:x*y,'/':lambda:x/y}[op]()
  cases.append(f'        arrayOf("{op}", "{a}", "{b}", "{v}")')
s='''package pb.evaluation
import kotlin.test.Test
import kotlin.test.assertEquals

/** 60 vectors generated with independent Python decimal, precision 12 / ROUND_HALF_UP.
 * These test the explicit evaluation model, not confirmed PB hardware behavior. */
class DecimalVectorsTest {
    @Test fun independentDecimalVectors() {
        val vectors = listOf(
'''+',\n'.join(cases)+'''
        )
        for ((op, a, b, expected) in vectors) {
            assertEquals(0, DecimalProbe.calculate(op, a, b).compareTo(DecimalProbe.parse(expected)), "$a $op $b expected $expected")
        }
    }
}
'''
p=r/'src/commonTest/kotlin/pb/evaluation/DecimalVectorsTest.kt';p.write_text(s)

p=r/'src/commonTest/kotlin/pb/evaluation/CandidateArithmeticVectorsTest.kt'
p.write_text(s.replace('class DecimalVectorsTest','class CandidateArithmeticVectorsTest').replace('DecimalProbe.calculate(op, a, b)','CandidateArithmeticProbe.calculate(op, a, b)'))
