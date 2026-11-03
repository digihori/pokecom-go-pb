# 共通数値基盤の技術試作

製品コードとは分離した評価用KMPプロジェクト。PBのBASICインタープリタやPlayerではない。

- Kotlin 2.4.21 / Gradle 9.5.0 / JDK 21
- bignum 0.3.10 / Coroutines 1.11.0 / Serialization JSON 1.12.0
- JVM、iosSimulatorArm64、iosArm64。Compose／Androidアプリはまだ追加しない。
- 評価モデル：有効数字12桁、ROUND_HALF_AWAY_FROM_ZERO。PB実機の丸め方として採用したものではない。

## 再現手順

このディレクトリでJDK 21を選択し、macOSではXcodeとiOS Simulatorランタイムを用意する。初回はGradle・依存・Kotlin/Nativeの取得が必要。実機の署名・インストールはこの試作の手順に含めない。

```sh
./gradlew jvmTest iosSimulatorArm64Test linkDebugTestIosArm64 linkReleaseFrameworkIosSimulatorArm64 linkReleaseFrameworkIosArm64 --continue --console=plain
```

**通常試験は現在失敗する。** 除算の既知の不一致を隠さず検出するためであり、成功したビルドとは扱わない。JVMのみの場合は`./gradlew jvmTest`。`--continue`で試験の失敗後も他ターゲットの確認を続ける。

追加精度の診断だけを個別確認する場合：

```sh
./gradlew jvmTest --tests '*GuardedDivision*' iosSimulatorArm64Test --tests '*GuardedDivision*' --console=plain
```

`guardedDivision`は24桁で除算して12桁へ丸める**診断用の別経路**。二重丸めや境界ケースの保証はなく、一般的な修正や本採用と扱わない。通常の`calculate`は元の失敗を再現する。

共通の固定60件はPython標準`decimal`を独立参照として生成し、Kotlin試験へ埋め込んでいる。再生成は`python3 tools/generate_vectors.py`。JVMでは固定seedの1,000件をJava BigDecimalと比較する。生成範囲はPBの数値範囲外も含み、汎用ライブラリを調べるものである。

初回評価時の通常試験は10メソッド（JVM）、8メソッド（iOS）。以後の候補試験を追加している。60件と1,000件はメソッド内の入力件数なので、テストメソッド数とは異なる。診断だけの実行では対象メソッドが絞られる。

試験HTML／XMLと生成Frameworkは`build/`、今回の記録は`results/`。`results`のログは実行時の作業パスを置換して保存している。詳細な評価と残課題は[評価報告](../../docs/foundation-evaluation-results.md)を参照。


## 除算補完の候補を評価する

`ExactDivisionProbe`は整数商・余りと分母の比較で一度だけ丸める。`CandidateArithmeticProbe`は除算のみこれを使用し、加減乗算は元の十進演算を使う評価用の構成。

```sh
python3 tools/generate_division_vectors.py
./gradlew jvmTest --tests '*CandidateArithmetic*' --tests '*ExactDivision*' iosSimulatorArm64Test --tests '*CandidateArithmetic*' --tests '*ExactDivision*' linkReleaseFrameworkIosSimulatorArm64 linkReleaseFrameworkIosArm64 --continue --console=plain
```

Python decimalによる同じ1,000組×3丸め方式の参照値をJVM／iOSで検査する。生成スクリプトはPython標準ライブラリだけを使う。候補用の試験は成功しているが、生ライブラリ除算を含む全件実行には既知の失敗が残る。

追加精度の診断は[二重丸めの反例](../../docs/decimal-division-evaluation.md)で一般解にならないことを確認した。詳細は同文書を参照。
