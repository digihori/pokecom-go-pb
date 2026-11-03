# 旧Pokecom GO（pokecom2）の実装調査

調査日: 2026-11-03

私が開発した旧CASIO版を、新プロジェクトのBASIC詳細仕様を整理するために調査した。以下は旧実装の読み取り結果であり、PB-100実機の仕様確定や、新版への採用決定ではない。

- 対象: [digihori/pokecom2](https://github.com/digihori/pokecom2)
- ブランチ: master
- 固定コミット: `9deb46a3c37c6cc2ae860cfc42df4297a4cf3988`
- app/build.gradle上の版: 1.07.00（versionCode 67）
- 調査方法: ソースを調査用フォルダへ取得し、実行経路を静的に読んだ。アプリのビルド・実行、実機比較、再現テストは未実施。旧コードの変更・新版の実装も行っていない。
- 本文のリンクはこのコミットに固定。旧READMEは実装と異なる箇所があるため、実際の処理を優先して記録した。

## 1. 全体像

| ファイル | 主な役割 | 新版への示唆 |
| --- | --- | --- |
| SBasic.java | 字句解析、式評価、命令実行、変数、FOR/GOSUB状態、容量計数 | PB固有動作の主要な参照元。UI・時間待ちも混在する |
| SourceFile.java | P0〜P9のソース、行番号順の保持、追加・置換・削除、リスト送り、行ごとの容量 | ページと行の操作、移行形式の参照元 |
| Common.java | アプリ内部コード表とPB用コード表 | 両者は別体系。表示コードを実機コードとして扱わない |
| Lcd.java / PbMain.java | 12桁表示、入力編集、スクロール、描画、実行スレッドと停止状態 | 実機風操作の参照元。Android依存と実行制御を切り分けたい |
| MainActivity.java / Keyboard.java | モード・キー・履歴・ファイル入出力・残量表示 | キー挙動・旧テキスト形式の確認に必要 |
| WaveOut.java | ソースの内部コード化、カセット信号・音の生成とAudioTrack再生 | Perl版に加える変換資産。WAV復号器ではない |

参照: [SBasic](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1)、[SourceFile](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SourceFile.java#L19)、[Common](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/Common.java#L7)。

旧実装は文字列をchar配列へ連結し、pcを動かして、その場でトークン化・評価する方式。事前に命令一覧へ分解する構造や、元ソース上の命令範囲を保持する構造は確認できない。MainActivityのstatic状態、Lcd、PbMain、Keyboard、WaveOutをインタープリタから直接参照する。

## 2. 直接入力とプログラムの関係

- `calc`は直接入力をprogへ設定し、`sbCmd`へ渡す。
- `run`は選択ページのソースを読み、行番号テーブルを作って`sbInterp`へ渡す。開始行指定の経路もある。
- 式の数値評価は共通の`evaluate` / `evalExp1`〜`evalExp6` / `atom`、文字列は`strOpe`系を使う。今回の「直接入力とプログラムで式評価を共通化したい」という構想の参照になる。
- コマンドの受付範囲は両者で異なる。例えば直接入力のPRINTはsbCmdのcaseにない。プログラム中のCLEARはVACと同じ変数消去として処理され、PROモードのCLEARはソース消去となる。
- RUN開始でラベル表は初期化するが、FOR/GOSUBスタックを明示的にclearする処理はrun内にない。中断後の再RUNなどは検証対象。

参照: [loadProg/run/calc/sbCmd](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L448)、[実行ループ](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L743)。

## 3. 字句解析とPB固有の作法

| 項目 | 旧実装で確認した処理 | 注意点 |
| --- | --- | --- |
| 空白省略 | 英字列を読み進め、Common.cmdTableの予約語に一致したところで切る | PRINTやSINの直後の引数を空白なしで読める設計。あらゆる省略形の保証ではない |
| 予約語認識 | cmdTableによる切り出しとkwTableによる命令検索の二段階 | 前者は大文字の完全一致、後者は小文字化。大小文字や空白の有無で差が出る可能性 |
| 複数命令 | `:`を区切りとして扱い、実行ループを継続 | デバッグ向けの独立した命令IDや原文範囲は保持しない |
| 閉じ括弧省略 | 通常の括弧式で、終端・改行・一部区切りを許容 | 配列参照、LEN/VAL等には閉じ括弧を要求する別処理がある。一律に省略可とはしない |
| 引用文字列 | 引用符または改行まで読み込む | 直接入力の終端や閉じ引用符省略の境界は検証が必要 |
| 比較演算 | `< > =`と内部比較記号、`<= >= <> != ==`を読む分岐 | 入力時の変換と実行時の変換が重複。putBackが変換後の文字数で戻ることにも注意 |
| 指数表現 | 内部EX/EMを数値トークン内でE+/E-へ変換 | トークンの原文長と変換後長が異なる |
| ページ指定 | `#`をBANKNUMとして扱う | GOTO/GOSUBのページ間移動で利用 |

参照: [getToken](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L3315)、[括弧式](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2580)、[putBack](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L3295)。

## 4. 式評価・数値計算

### 4.1 演算の構造

低い優先順位から、比較 → 加減 → 乗除・剰余 → べき乗 → 単項符号 → 括弧・値・関数という再帰下降構造。

- 加減、乗除はループで左から処理する。
- べき乗はコメントでPBの左結合を意図している。実装は先読みも含むため、複雑な式の結果は再現確認が必要。
- 単項符号をべき乗より先に処理する構造。`-2^2`、`2^-2`、`2^3^2`は実機比較の重要例になる。
- 数値比較の結果は1または0。
- 関数の引数を読む評価階層が一律ではない。SIN等はevalExp5、LOG/LN/SQRはevalExp6を使う。括弧なし関数と符号・べき乗の組合せは個別に検証する。

参照: [evaluate〜atom](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2357)。

### 4.2 精度と丸め

- 数値リテラル・変数はBigDecimal。
- 加減はBigDecimalで処理。乗算は計算後に小数部99桁へHALF_UP、除算も小数部99桁・HALF_UP。
- べき乗、三角関数・対数・平方根・指数関数、PI、乱数はdoubleを経由し、`new BigDecimal(double)`で戻す箇所がある。
- 数値表示もdoubleへ変換し、通常は有効数字10桁相当の書式を用いる。SET E/F系で表示処理が分岐する。
- INTは負数を負の無限大側へ丸める構成、FRACは1による剰余、SGNは符号を返す。
- RNDは第2引数を-99〜99として検査し、`scale = -n - 1`でHALF_UPする。
- RAN#はMath.random。乱数状態の外部保持やシード制御は確認できない。

**BigDecimal採用＝全計算が実機相当／無誤差ではない。** 新版では演算値・保持精度・表示丸め・範囲外エラーを分けて定義する。旧版の99桁設定を実機仕様として採用しない。

参照: [乗除](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2479)、[関数](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2641)、[数値表示](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L331)。

## 5. 変数・文字列・ページ

- A〜Zの26スロットに数値と文字列の配列を持つ。数値代入で対応文字列を空にし、文字列代入で数値を0にする。
- A$等の文字列は最大7文字、独立した`$`は最大30文字として代入・INPUT時に検査。
- `A(n)`等は基底変数の位置＋オフセットを参照する。A(1)とB等の対応が生じる設計で、一般的な独立配列とは異なる。
- DEFMで追加変数を確保。通常は最大68、拡張時は最大196の追加数を検査。追加1個を8ステップ分として残量へ反映する。
- VACは基本・追加変数、`$`、最終計算値を消去する。
- 文字列連結は`+`。文字列比較はアプリ内部コードをPB文字コードへ変換して順序比較する。UnicodeやASCIIの順序で代替しないことが重要。
- MIDは`$`を対象とし、開始位置は1起点として処理。範囲外は空文字を返す分岐がある。
- LEN、VAL、KEY、MID、STR$にはそれぞれ数値／文字列の処理経路がある。VALは先頭の数字列を抜き出す正規表現を使うため、小数点・符号等で非対称な処理となる可能性がある。

参照: [代入/VAC](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L984)、[文字列操作](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2042)、[変数参照/DEFM](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L3180)。

## 6. 命令・関数の棚卸し

以下は実行処理の存在を示す。全構文の正当性や全モードでの利用を保証しない。

| 区分 | 確認した処理 |
| --- | --- |
| 実行・編集コマンド | RUN（開始行指定経路あり）、LIST、CLEAR / CLEAR A、VAC、DEFM、SET、SAVE、LOADの受付分岐 |
| 出力・入力 | PRINT、CSR、INPUT、KEYの数値・文字列経路 |
| 分岐 | GOTO、GOSUB、RETURN、IF THEN、IF `;`、ON GOTO/GOSUB |
| ループ・終了 | FOR TO STEP NEXT、STOP、END |
| 追加の実行処理 | LET、REM、READ、DATA、RESTORE、BEEP |
| 数学関数 | SIN/COS/TAN、ASN/ACS/ATN、LOG/LN/EXP/SQR、ABS/SGN/INT/FRAC、RND、RAN#、PI |
| 文字列関数 | LEN、VAL、MID / MID$、STR$、KEY / KEY$の経路 |
| 角度・表示 | 実行中MODE 4/5/6でDEG/RAD/GRAD。7/8は分岐のみ。SET E0〜E8、F0〜F9、Nの処理 |

注意:

- LOADはsbCmdで即returnするだけで、BASICコマンドとしての読込処理はない。テキスト読込はアプリのファイル機能にある。
- DEFM等は直接入力側にあり、プログラム側の同名caseがないものもある。キーワード一覧だけで実行可否を決めない。
- PUT / GET / VAR等はPB用コード表にあるが、SBasicの実行処理としては確認できない。
- LET/REM/ON/READ/DATA/RESTORE/STR$/MID$/BEEP等はPB実機由来か独自拡張かを資料で分類する。表にあるだけでPB-100互換命令に含めない。
- 剰余`%`はコメントにも「PBにはない」とあり、旧版拡張として明確に区別する。
- Commonの予約語切り出し表にはRNDが見当たらない一方、kwTableとatomにはある。空白省略形の受付差を検証する。

参照: [キーワード表](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L150)、[コマンド側](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L537)、[プログラム側](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L782)。

## 7. 制御フローと停止・再開

- 行番号を文字列キー、pcを値とするテーブルを事前作成。GOTO/GOSUBは数式を読み、整数へ切り捨てた行番号を検索する。
- GOTO # / GOSUB #でページを切り替える。GOSUBは戻り先のページとpcを保存する。
- IFの偽は行末まで飛ばす。真はTHENまたは`;`を要求し、THENの後が数値・ページ指定なら分岐、変数なら後続を見て分岐か代入等かを判断する。
- FOR状態は変数、終値、増分、戻りpc。NEXTは対応する変数が見つかるまでスタックをpopし、加算後に終値を判定する。
- STOP文はPbMainのpauseを立てる。実行ループは200ms待ちながら状態解除を待ち、EXEでpauseを解除する。
- PRINTも出力条件により同じpauseを利用する。
- STOPキーはSBasic.sbExitでforcedExitを立てる。これはpauseとは異なり、実行を終了させる。
- `cont()`はあるが、今回確認した呼出し箇所では外部からの利用は見当たらない。旧版の通常の再開は同じ実行スレッドのpause解除。
- 命令単位のデバッガ、変数変更API、ブレークポイント、履歴巻き戻しは確認できない。printTraceは行の残りをログやdebugTextに書く処理。

READMEの「中断後に再開できない」はSTOPキーの終了と整合するが、STOP文・PRINT後のpauseまで再開不可と読むのは不正確。

参照: [分岐](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1346)、[FOR/NEXT](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1538)、[GOSUB](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1774)、[pause](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/PbMain.java#L282)、[STOPキー/EXE](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/Lcd.java#L390)。

## 8. PRINT・INPUT・キー入力

- PRINTは文字列・数値・CSRを組み合わせて出力を構成。数値が非負なら先頭へ空白を付ける。
- CSRは0〜11を検査し、出力用StringBuilderの指定位置を置換する。
- セミコロンは連結・継続に関係し、カンマでは出力後にpauseし、解除後に続きを処理するためのprintPauseを保持する。
- Lcd.bprintは最初の12文字を表示。**12文字を超える場合**に800ms待ち、その後300msごとに1文字ずつ左へ送る。これは旧実装のタイミングで、実機準拠値かは未確認。
- INPUTは表示用プロンプトに`?`を付け、共有inTextを50ms間隔で待つ。数値はBigDecimalへ直接変換する経路であり、入力値に計算式を許す実装ではない。
- 空文字は待機終了条件にならない。停止中の入力や空文字入力をどう扱うかは、新版の仕様として定義が必要。
- KEYは押されているボタン状態配列の最初の1個を読み、通常面のキーコードを返す。未押下では0（文字列側では空文字）。同時押しの一般的なキュー処理ではない。
- LCD入力バッファは128要素、通常の文字入力の上限判定は127未満。これを実機の1行上限と断定しない。
- プログラム一覧の上下送りはMainActivityとSourceFileで実装。入力履歴8件の上下送りも別に存在する。

参照: [PRINT](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1144)、[スクロール](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/Lcd.java#L271)、[INPUT](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1617)、[押下キー](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/Keyboard.java#L47)。

## 9. ソース保存・文字コード・容量

### ソースと文字

- ファイル入出力は`[P0]`〜`[P9]`のページ指定と行番号付きテキスト。読込時にCRを読み捨て、行番号で始まらない通常行を無視する。
- 特殊記号はCommon.cmdTableに従ってアプリ内部の文字へ変換。保存時は比較記号を`<> <= >=`、他の特殊記号をエスケープへ戻す。
- **旧アプリの内部コードと、PB実機の内部コードは異なる。** 例: `\PI`は旧アプリで0xF3、PBコードでは0x1B。`\UA`は読込時に`^`へ寄せる処理もある。
- PB文字・予約語のコード表は、Perl版より多くの語を含む。0xC3は旧アプリ表がVAR、Perl版がVER。追加コードを実機仕様と見なさず照合する。
- エスケープ定義の参照元は、既に決めたPerl版を維持する。旧アプリの入力変換の不具合や内部番号まで新しい交換形式へ持ち込まない。

### 容量計数

- SourceFileは1行につき`3 + 本文のgetProgSteps`として保持。全ページを合計する。
- 本文計数は空白・タブを無視し、予約語を原則1ステップ、引用内を文字数分として扱う。LEN/VAL/MIDの括弧を予約語に含めるための補正がある。
- MainActivityは544または1,568からプログラム使用量と追加変数数×8を引き、負数なら0にして表示する。
- 調査した追加・読込・実行経路には、この残量を使ってプログラム容量超過を拒否する処理は確認できない。DEFMの追加数上限は別途検査される。
- READMEにも容量計数と実機との差がある旨を記載。プログラムの正確な容量、追加変数との競合、ページ区切り等の扱いは再検証する。
- `progLength = 3000`などの固定バッファがある。デスクトップで実機容量制限を外すこととは別に、実装上のサイズ制限を整理する必要がある。

参照: [ファイル読込](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/MainActivity.java#L1022)、[ファイル保存](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/MainActivity.java#L1268)、[行容量](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SourceFile.java#L42)、[本文容量](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L3495)、[残量表示](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/MainActivity.java#L1444)。

## 10. エラーと旧実装の要確認箇所

エラー番号はSystem=0、Memory=1、Syntax=2、Math=3、Undefined line=4、Argument=5、Variable=6、Nesting=7、Option=9。handleErrは実行位置から行を探し、ERR番号とP番号・行番号を表示して例外を投げる。全エラーがこの経路へ正規化されるわけではない。

以下はソース上の懸念。実行再現は未実施で、実機仕様や互換要求とは区別する。

| 箇所 | 確認した記述・懸念 | 確認するケース |
| --- | --- | --- |
| FOR開始判定 | 初期値を代入後、その同じ変数値と初期値を比較。終値との比較になっていない | 初期値が既に終値を越える正負STEP |
| STEP=0 | BigDecimalのstepへ`equals(0)`で検査しており、Integerとの比較になる | STEP 0のエラー・停止条件 |
| RUN開始 | FOR/GOSUBスタックの明示的初期化がない | 未完了ループ・サブルーチンから終了して再RUN |
| 配列境界 | 負のオフセットの下限検査不足、文字列参照の上限比較が一部`>` | 負数、ちょうど上限、拡張なし |
| putBack | 変換後トークン長でpcを戻す | 複数字比較記号、PI、指数記号、閉じ引用符省略 |
| findEOS | 引用符を区別せずコロンを探す。コメントにも懸念あり | ON等で文字列内にコロンがある行 |
| VAL | 先頭の数字列を抜き出してから変換 | 小数、負数、指数、数字に続く文字 |
| INPUT待機 | 空文字で待ち続ける。pauseでも待機を抜ける | 空文字・入力中の停止・再開 |
| 読込時の比較変換 | `!=`の条件は演算子優先順位によりnoencode条件の外 | 引用文字列の中の`!=`を保持できるか |
| サイズ境界 | 読込行・実行ソース・保存・音声符号化が固定配列 | 長い行、多ページ、エスケープ展開での超過 |

参照: [FOR/STEP](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1538)、[エラー](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L3606)、[読込変換](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/MainActivity.java#L1115)。

## 11. カセット信号の資産

WaveOutには、ページ別ソースをPB用コードへ変換するencode、SAVE A相当の信号生成、AudioTrackによる再生がある。信号波形はPerl版同様、1を9サンプル×8周期、0を18サンプル×4周期として保持し、LSB先の8ビットとパリティ・停止ビットを出す。

ソース変換と音声再生の両方が参照になるが、WaveOutをそのままWAVファイルの入出力ライブラリとは扱わない。今回必要なWAV復号・波形解析の基盤は別途必要。

参照: [WaveOut.encode](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/WaveOut.java#L145)、[フレーム生成](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/WaveOut.java#L514)。

## 12. 新版の仕様へつなぐ方針案

### 参照資産として活用する部分

- PB固有の省略記法、IFの作法、ページ間移動、共有変数・文字列、PRINT/CSRの実例。
- 正確な字形の照合元となるLcdの固定キャラクタ描画データ。
- 旧テキスト形式、エスケープ、キー配列、上下リスト送り、音声符号化。

### 新たに設計する必要がある部分

- 命令と元ソース位置を対応付け、命令の境界で安全に止める仕組み。
- 実行中／入力待ち／表示送り／PRINT待ち／STOP文／デバッガ停止／終了を区別した状態。
- 変数・FOR・GOSUB状態の参照と停止中の変更。UIを直接呼ばずに実行結果を環境へ渡す境界。
- 実機相当の数値精度と容量計数、転送先への適合判定。
- Androidや特定UIから独立し、機能を絞った特殊環境でも利用できる実行基盤。

旧版の単純移植より、仕様とデータを参照して実行基盤を再設計する方が今回の要求に合うと考えられる。ただし再実装の採否・技術選定はまだ確定しない。

## 13. 次に確定したい詳細仕様と確認例

| 優先 | 詳細仕様 | 比較・確認の例 |
| --- | --- | --- |
| 先行 | 対象方言と独自拡張の境界 | 予約語表と実機命令表を照合。旧版だけのコードを識別 |
| 先行 | 省略文法と演算優先順位 | PRINT/SINの空白省略、閉じ括弧、連続べき乗、負数とべき乗 |
| 先行 | 数値保持・丸め・範囲 | 0.1+0.2、1/3、三角関数の特殊角、桁・指数の上下限 |
| 先行 | 停止・再開・命令境界 | 1行の複数命令、IF、FOR/NEXT、GOSUB、PRINT待ち、INPUT中 |
| 先行 | 文字と容量 | 引用内空白・記号、括弧込み予約語、行番号・ページ区切り、DEFM |
| 続行 | 変数・配列・文字列 | A(1)/B、追加変数、7/30文字境界、文字比較、MID/VAL |
| 続行 | LCD・キー・速度 | 12/13文字、CSR 0/11、同時押し、スクロールと速度調整 |
| 続行 | 移行と転送 | 旧保存ソース、Perl版との符号化比較、実機成功例WAV |

期待結果はマニュアルと実機から作り、旧実装の結果は比較対象の一つとする。現在のテストはテンプレートの加算確認等で、BASIC互換性の自動回帰テスト群は確認できない。検証例の作成・実行は今後の作業。
