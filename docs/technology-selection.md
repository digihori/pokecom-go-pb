# 主要技術の選定

作成日: 2026-11-03 / 第1版

状態: 主要5OS向けの採用方針を選定。依存ライブラリの版固定・評価試作・実装は未実施。公式資料に記載された対応と、本プロジェクトでの動作確認を区別する。

参照: [基本設計](basic-design.md)、[BASIC詳細仕様](basic-specification.md)、[実装計画](design-and-implementation-plan.md)。

続く選定結果は [技術選定 第2段階](technology-selection-details.md) に記載する。実行制御・状態通知・保存・WAV/QR・MCPの方式は同書を優先する。

## 1. 選定の優先順位

1. Windows / macOS / Linux / Android / iOSで、同じBASICの動作を保つ。
2. デスクトップのデバッグと、モバイルPlayerを無理なく開発・保守できる。
3. 数値計算、文字、実行状態の共通化を確保する。
4. WAV・QR・MCPは共通基盤を汚さず追加する。

Windows CEの想定機器はBrain。ただし、Windows CEとBrainuxは必要なら対象外としてよく、主要5OSに最適な構成を優先する。両者への移植を、言語・UIの採用条件にしない。現時点で移植経路は約束しない。

## 2. 選定結果

| 項目 | 採用方針 | 状態 |
| --- | --- | --- |
| 言語・共通実行基盤 | Kotlin / Kotlin Multiplatform（KMP） | 主要方針として選定 |
| デスクトップ | Kotlin/JVM + Compose Multiplatform | 主要方針として選定 |
| Android Player | Kotlin/JVM系 + Compose（Android側はJetpack Compose） | 主要方針として選定 |
| iOS Player | Kotlin/Native + Compose Multiplatform、起動・権限等はiOS接続層 | 主要方針として選定 |
| 文法・命令処理 | 共通Kotlinで実装し、命令表現・原文対応・継続状態を保持 | 基本設計を具体化 |
| 十進数演算 | 共通のPB数値型で隠蔽し、純KotlinのBigDecimal相当実装を使う | 方針選定。ライブラリは評価候補 |
| 十進数ライブラリ | ionspin/kotlin-multiplatform-bignumを第一評価候補 | API・計算結果・現行ツールとの適合は未検証 |
| ビルド | Gradle Kotlin DSL、KMPのソースセットで分割 | 方針選定。具体バージョンは後で固定 |
| 共通試験 | commonTestの仕様試験をJVM・Android・iOSで実行する構成 | 方針選定。試験は未作成 |
| 実行制御・状態通知 | Coroutines＋Channel、UI状態はStateFlow | 第2段階で方式選定 |
| 保存・メタ情報 | 旧形式のBASICテキスト＋kotlinx.serialization JSON | 第2段階で方式選定 |
| 外部機能 | WAV/QR/MCPは個別モジュール。詳細は第2段階 | 一部の版・OS接続は未確定 |

KMPとComposeは別の役割。BASIC基盤にCompose依存を入れず、UIなしでも解析・実行を検証できる構成を維持する。

Android、iOS、Desktop/JVMはKMPとComposeの公式資料でStableとされる。この記載は、カメラやコントローラ等の全機能が共通APIだけで完結するという意味ではない。[公式の対応・安定性](https://kotlinlang.org/docs/multiplatform/supported-platforms.html)

## 3. 比較と選定理由

| 案 | 良い点 | 今回の判断 |
| --- | --- | --- |
| KMP + Compose | Kotlinで実行・状態・UI接続をそろえやすい。デスクトップとPlayerで必要なUIだけ作り分けられる | 第一案として選定 |
| C++コア + Qt UI | C++の実行基盤とUIを分離でき、Qtに主要5OSの対応がある | 成立する案。ただし今回は移植性よりモバイルを含む開発・保守の一貫性を優先し、選定しない |
| C++コア + Kotlin/Swift等のUI | UIを各OSへ合わせられる | 型・文字列・状態・寿命・非同期イベントの言語境界と複数ビルドを管理する負担が増えるため第一案にしない |
| Flutter + Dart | 主要5OSを対象にでき、UI共通化の選択肢になる | 有力な代替案だが、今回の旧Java実装の理解をKotlinへつなぎ、実行とUIを同じ系統で保守する構成を優先 |
| Rustコア + 環境別UI | 独立した実行ライブラリを作る選択肢 | 本製品の要求から、追加の言語境界を負ってまで選ぶ理由を現時点で設けない |

ここでの開発負担の比較は本プロジェクトの設計判断であり、言語・フレームワーク一般の性能ランキングではない。

C++はモバイルで使用できないわけではない。AndroidはNDK/JNIによる接続、SwiftにもC++相互運用の手段がある。QtでUIまで統一すれば手書きの橋渡しを減らせる。しかし、C++採用が主要5OSで最も扱いやすいとは判断しない。[Android NDK](https://developer.android.com/ndk/guides)、[Swift/C++相互運用](https://www.swift.org/documentation/cxx-interop/)、[Qt対応環境](https://doc.qt.io/qt-6/supported-platforms.html)

Composeは共通KotlinからUIを記述できるが、デスクトップのウィンドウ管理やiOSのUIKit連携等には環境固有APIがある。本プロジェクトでも環境別接続を残す。[Composeの共通部分と環境固有部分](https://kotlinlang.org/docs/multiplatform/compose-multiplatform-and-jetpack-compose.html)

## 4. モジュール・ターゲット構成案

以下は構成の名称案で、ディレクトリやビルド設定はまだ作成しない。

- pb-core: PB文字、数値の公開型、文法、式・命令、変数と実行状態。共通Kotlin。
- pb-session: 入出力・実行量・停止再開・要求ID等。共通Kotlin。UIやOSのイベントループには依存しない。
- pb-source: 原文・ページ・旧保存形式・エスケープ・原文対応・容量計数。共通Kotlin。
- pb-devtools: 分解表示用情報、状態参照、変数変更等。Playerのアプリ構成から外せる。
- pb-transfer: WAV/QRのデータ処理と適合確認。音声・カメラの取得は接続層へ置く。
- desktop-app: JVM向けデスクトップUIとファイル・ウィンドウ・MCP接続。
- player-ui: Android/iOS向けの実機風Compose UI。LCD・ソフトキー等は共有する。
- android-app / ios-app: 起動・ライフサイクル・ファイル選択・カメラ・コントローラ等の接続。

最初から全てを別ライブラリに分割する必要はない。責務と依存方向を保ち、初期のビルド構成は必要最小限にする。

JavaのBigDecimal、Android API、JVMのファイル・スレッドAPIをcommonMainへ入れない。OS機能はインターフェースや必要なexpect/actualを通す。全機能をexpect/actualにするのではなく、共通の処理は共通に保つ。

iOSでは共通KotlinをNative向けにビルドし、Player UIと組み合わせる。デスクトップとAndroidはJVM向けの共通実装を使う。アプリ全体のビルドやApple側の設定まで、完全に同一になるという意味ではない。

## 5. Android/iOS共通のBigDecimal相当手段

### 第一評価候補

[ionspin/kotlin-multiplatform-bignum](https://github.com/ionspin/kotlin-multiplatform-bignum)は、純Kotlinの任意精度演算とBigDecimal、精度・丸め・scaleを指定するDecimalModeを提供する。Java BigDecimalの置換候補になるが、APIや演算規則が完全一致するものではない。

現行の[ビルド定義](https://github.com/ionspin/kotlin-multiplatform-bignum/blob/main/bignum/build.gradle.kts)でJVMとiOS実機・シミュレータのターゲットを確認した。AndroidはJVM向け利用を評価し、Android Nativeターゲットの存在だけをAndroidアプリでの確認済み根拠にはしない。実際の公開アーティファクトと採用Kotlin版との組合せは、依存を固定する前に確認する。

READMEでは1.0までAPI変更の可能性が記載されている。四則演算の候補として有望だが、PBで必要な数学関数一式や丸めの一致まで確認した状態ではない。[ライブラリの仕様・注意点](https://github.com/ionspin/kotlin-multiplatform-bignum#readme)

### 利用方針

- BASICの数値をPBNumber等の共通型で包み、ライブラリ型を全モジュールへ漏らさない。
- 数値リテラルは十進文字列から読む。いったんDoubleへ変換してからBigDecimal化しない。
- 除算の精度・丸め・桁あふれ・ゼロ除算を明示し、ライブラリの既定値へ依存しない。
- 代入・演算結果・LCD表示・SET/RNDで、それぞれ必要な丸め方を区別する。
- 同じ純Kotlin実装を主要ターゲットで使う案を優先する。Androidだけjava.math.BigDecimal、iOSだけ別実装という構成を第一案にしない。
- BigDecimal的な型があっても、SIN/COS等が十進の同じ精度で計算されるとは限らない。数学関数は別に評価する。
- 0.1+0.2のような十進の有限演算と、1/3や三角関数の近似計算を区別する。「全演算が無誤差」とはしない。

### 採用前に確認すること

1. JVM・Android・iOSシミュレータ／実機向けで同じ文字列を読み、同じ四則演算・比較・丸め結果を得られること。
2. 1/3、正負の中間値、非常に小さい／大きい値、桁・指数制限、RND・INT・FRACの処理。
3. PBの保持精度を定めた場合の挙動。旧版の小数部99桁方式をそのまま継承するかは別の判断。
4. 数学関数・小数べき乗・角度単位の実装手段。ライブラリだけで足りなければ、数値アダプタ内部の補完候補を比較する。
5. 現行ツールチェーンとの互換性、ライセンス、依存の更新・固定方法。

自作の多倍長演算を最初から書く方針にはしない。mpdecimalやBoost等のC/C++系も調査したが、これらを全面採用して言語境界を増やす構成は、共通Kotlin候補の適合評価後に必要なら比較する。

## 6. UI・描画・外部連携

- デスクトップとPlayerの画面構成は別にする。共有するのはBASIC状態、LCDの文字データ、可能な範囲の描画部品とキー部品。
- デスクトップの原文・命令分解・変数・FOR/GOSUB表示を、Playerへ一式持ち込まない。
- LCDは固定字形データを使ってCanvas等で描画する案。12セルの状態とスクロール計算は共通のセッション側へ置く。
- 外部エディタとの連携はまず明示読込を基本設計案とする。JVM側のファイル通知等は差し替え可能な接続層へ置く。
- WAVのPB信号処理・文字変換は共通Kotlinで実装する方針。音声ファイル形式の対応範囲と既存Studioの波形解析からの再利用は別途確認。
- QRのデータ形式は共通に定義し、撮像・画像復号のライブラリはAndroid/iOSで適切なものを後から選べる構成にする。現時点で特定のC++バーコードライブラリを必須にしない。
- コントローラは論理キーへの接続として環境別に提供する。ライブラリ未選定を理由に、BASIC側へOSコードを入れない。
- MCPはデスクトップの開発支援へ接続。第2段階で公式Kotlin SDKのJVMサーバー＋ローカルStreamable HTTPを第一方式として選定。SDKの版固定・接続試験は未実施。SDKをコアへ依存させない。[MCP公式SDK一覧](https://modelcontextprotocol.io/docs/sdk)

## 7. ビルド・配布・検証

GradleのKMP構成で共通実装とターゲット固有接続を分ける。Kotlin・Compose・Gradle・Androidプラグイン等の具体的な組合せは、互換性を確認して一式固定する。常に最新版を自動取得する運用にはしない。

デスクトップはComposeの配布機能を第一案とする。公式機能は必要なJavaランタイムを含む配布物を作れるが、OS別のパッケージ生成は対応OSで行う前提がある。macOS上だけで3OSの配布物を作れるとは扱わない。[公式のデスクトップ配布](https://kotlinlang.org/docs/multiplatform/compose-native-distribution.html)

技術評価の最初の対象は、十進数演算とiOS向けの共通基盤ビルド。デスクトップを完成させてから初めてiOSの依存問題を発見する順序にしない。評価コードの作成は、実装・試作へ進む段階で行う。

試験結果はJVM／Android／iOS別に記録し、同じ論理入力・時刻・乱数列による連続実行と命令単位実行を比較する。主要OSの配布確認と、BASICの共通仕様試験は分ける。

## 8. 基本設計からの変更

- 言語・UI技術の未選定状態から、KMP＋Composeを主要方針として選定した。
- 特殊環境への配慮を技術選定の先行条件にする案を変更し、主要5OSを優先する。
- Brain上のWindows CE、Brainuxは対象外となってもよい探索候補。共通Kotlinから設定だけで移植できるとはしない。
- UIと実行の分離、命令単位実行、原文対応、待機の継続状態という基本設計は維持する。
- 十進数ライブラリの本採用、数値精度、数学関数の方式、OS別周辺機能、配布条件・最低OS版は未決。

本選定は文書上の方針決定で、実装開始を意味しない。次の作業は選定内容のレビューと、数値・iOS共通基盤の評価項目の具体化。


## 9. 評価計画の具体化

[バージョン構成・数値計算・iOS共通基盤の評価計画](version-and-foundation-evaluation.md)に評価開始候補、試験ケース、合格条件、実施順序を定めた。実装・試作は未着手であり、ここに記載した版は動作検証済みの構成ではない。
