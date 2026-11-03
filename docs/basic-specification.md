# BASIC詳細仕様 — pokecom2実装基準

作成日: 2026-11-03 / 第1版

## 1. 目的と仕様の基準

私が開発した旧Pokecom GOのBASICを、新プロジェクトの設計に利用できる形で整理する。本書の基準は **pokecom2のコード** とする。実機資料がそろうまで仕様化を待つのではなく、まず旧実装から言語と実行動作の基準を起こす。

- リポジトリ: [digihori/pokecom2](https://github.com/digihori/pokecom2)
- 基準コミット: `9deb46a3c37c6cc2ae860cfc42df4297a4cf3988`（master、app版1.07.00）
- 中心となるコード: SBasic.java、Common.java、SourceFile.java、Lcd.java、PbMain.java、MainActivity.java、Keyboard.java。
- 調査は静的なコード読解。旧アプリの実行・ビルド・実機照合は未実施。
- 「処理あり」はコード経路の存在を示し、全ての書式・引数で正常動作する保証ではない。
- 本書は旧実装の仕様基準。旧版の明らかな実装上の不整合まで新版で再現する決定ではない。独自拡張の採否・修正方針は別に決める。

構造・移植上の論点は [旧版実装調査](references/pokecom2-analysis.md)、特殊記号の交換形式は [エスケープ仕様](references/escape-codes.md) を参照する。

## 2. 用語と記法

- ページ: P0〜P9のプログラム領域。旧コードではbankと呼ぶ。
- 行番号: プログラム中の行を識別する番号。
- 命令: `:`で連結できる実行処理。複数命令を含む行がある。
- ステップ数: プログラムや追加変数の容量。デバッガのステップ実行とは別。
- `数値式`、`文字列式`、`変数`等は説明用の記号。表の角括弧`[ ... ]`は省略可能部分を示し、入力する文字ではない。
- 以下の書式はコードに対応する代表形であり、完全な形式文法ではない。省略や境界動作は各節を優先する。

## 3. プログラム・モード・ソース

### 3.1 ページと行

- プログラムは10ページ。各ページは行番号で並べ替えて保持する。
- 行番号と本文の間へ空白を補って保持する。行番号直後のコロンも区切りとして読み込む処理がある。
- 同一行番号への入力は置換、本文のない行番号だけの入力は削除となる。
- 通常の追加経路と一括読込経路は異なるため、重複行の扱いが一律とは限らない。
- 行番号を1〜9999に制限する処理はカセット符号化にはあるが、SourceFileの通常追加に同じ制限はない。新版の行番号範囲は採用仕様として明示する必要がある。
- 実行前に選択ページのソースを連結し、行番号と文字位置の対応を作る。

### 3.2 モード

- RUNモード: 直接計算・実行コマンドとプログラム実行。
- PROモード: 行の入力・編集・一覧・消去。
- SAVEモード: 音声保存処理中のアプリ状態。言語一般の編集モードではない。
- 角度単位はDEG / RAD / GRAD。初期値はDEG。

### 3.3 テキスト形式

保存形式はページ指定`[P0]`〜`[P9]`と行番号付きのテキスト。特殊記号はエスケープ表現を使う。読込ではCRを除去し、通常行のうち行番号で始まらないものを無視する。

旧版のアプリ内部文字番号とPB実機コードは別体系。新しい保存・QR・WAVの仕様では、両者を区別する。

根拠: [SourceFile](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SourceFile.java#L42)、[ソース読込](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/MainActivity.java#L1022)。

## 4. 字句・省略規則

| 項目 | コードから読み取れる規則 |
| --- | --- |
| 空白・タブ | トークン取得の先頭で読み飛ばす。ただしトークン内部の区切り判定と完全に同じ規則ではない |
| 命令と引数 | 予約語に一致した時点で英字列の読取りを切るため、`SINA`や`PRINT CSR1;"ABC"`のような書き方を意図している |
| 空白の全面省略 | 保証しない。数字列は区切りまで読むので、命令と引数の空白省略と、任意の空白を全て削除することは別 |
| 大小文字 | 最終的なキーワード検索は小文字化するが、途中の予約語判定は大文字完全一致。大文字を基準表記とし、小文字の同等動作は保証しない |
| 命令区切り | 引用外の`:`。改行は行末、プログラム終端は別トークン |
| 引用文字列 | `"`から次の`"`または改行までを文字列として読む。未閉鎖文字列の終端境界は不安定なため要検証 |
| 数値 | 数字または`.`から始め、区切りまでをBigDecimalへ渡す。指数記号EX/EMをE+/E-へ変換する |
| 比較記号 | `< > =`、内部LE/GE/NE、および`<= >= <> != ==`を読む分岐がある |
| ページ指定 | `#`に続く数値式をページ番号として使う経路がある |
| 特殊記号 | テキスト読込でエスケープを展開。`\UA`をべき乗記号`^`へ寄せる経路がある |

### 閉じ括弧の省略

一律の「閉じ括弧は省略可」ではない。

- 通常の数値括弧式は、`)`以外にプログラム終端・改行・一部区切りを許容する。
- 通常括弧式で`:`や`;`を読んだ場合は、その区切りも消費する処理がある。後続命令との組合せは要検証。
- 数値・文字列の配列添字は`)`を要求する。
- LEN / VALは専用処理で`)`を要求する。
- MID / STR$には`)`以外にコロン・改行を受け付ける分岐がある。終端条件を通常括弧式と同一視しない。

根拠: [getToken](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L3315)、[括弧式](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2580)。

## 5. 数値式・計算

### 5.1 演算優先順位

低い方から次の順。旧コードの呼出し構造を示す。

| 順位 | 演算 | 処理 |
| --- | --- | --- |
| 1 | `< <= > >= = <>` | 比較。真は1、偽は0。右辺は比較式へ再帰する |
| 2 | `+ -` | 加減。左から順に処理 |
| 3 | `* / %` | 乗除・剰余。左から順に処理。`%`はPBにはない旧版拡張とのコメントあり |
| 4 | `^` | べき乗。左結合を意図した実装。ただし先読み処理があるため複雑な連続式は要確認 |
| 5 | 単項`+ -` | 符号を処理後、べき乗側へ戻る構造 |
| 6 | 括弧、値、変数、関数 | 関数ごとに引数を読む階層が異なる |

`-2^2`、`2^-2`、`2^3^2`などの結果は、コードの構造からの見込みと、旧版を実行した観測結果を分けて確認する。一般的なBASICの優先順位で置き換えない。

### 5.2 数値の保持・丸め

- リテラル・数値変数はBigDecimal。
- 加減はBigDecimalの加減算。
- 乗算は結果を小数部99桁、HALF_UPへ丸める。除算も小数部99桁、HALF_UP。除数0はERR3。
- 剰余はBigDecimal.remainderを使い、除数0はERR3。
- べき乗と多くの数学関数はdouble経由。結果をnew BigDecimal(double)へ戻すため、十進小数としての誤差が入り得る。
- 数値全体に対する実機相当の桁数・指数範囲の一貫した検査は確認できない。
- 整数が必要な箇所にはintValueやROUND_DOWNを使う。関数・命令によって小数・範囲外の扱いが異なる。

### 5.3 数値の表示

- 通常表示はdouble化して原則`%.10g`相当。0の場合は別の書式を使う。
- SET F0〜F9は小数部をHALF_UPで丸め、その後に表示用書式へ変換する。固定小数点以下の桁数を必ず保持する表示ではなく、末尾0を除去する処理もある。
- SET E0〜E8は指数表示。E0では桁指定を8として扱い、負数の場合の調整もある。
- SET NはE/Fの指定を解除する。
- 表示用のE+ / E-は内部EX / EMへ置換する。
- 計算結果の保持精度と、表示精度は別。

根拠: [式評価](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2357)、[数値表示](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L331)。

## 6. 変数・文字列・追加メモリ

| 種類 | 規則 |
| --- | --- |
| 数値変数 | A〜Zの26スロット。初期値0 |
| 文字列変数 | A$〜Z$。最大7文字として代入・INPUT時に検査。初期値は空文字 |
| 独立文字列 | `$`。最大30文字として代入・INPUT時に検査 |
| 添字付き変数 | A(n)、A$(n)等。基底変数の位置＋数値式をint化したオフセット。同一領域を参照し、独立配列の宣言ではない |
| 追加変数 | DEFM nで追加。通常最大68個、メモリ拡張時最大196個。総数は26+n |
| 領域の共有 | 数値代入で対応文字列を空にし、文字列代入で対応数値を0にする |
| 型の検査 | 空でない文字列が入った領域の数値参照はERR6となる経路がある |

- DEFM 0で追加領域を解放する。異なる追加数へ変更すると追加領域を再確保・初期化する。同数の場合は再確保しない。
- 追加変数1個を8ステップとして容量表示へ算入する。
- VACは基本・追加変数、独立文字列`$`、最終計算値を初期化する。
- 文字列式は`+`で連結できる。比較時はPBキャラクタコード順に変換して辞書順に比較する。
- 文字数は展開後の内部文字列長で扱う経路。エスケープのテキスト長を、そのまま実機文字数と数えない。
- 負の添字、一部の上限比較、READでの長さ検査には不整合があり、第13節に分離する。

根拠: [代入とVAC](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L984)、[変数参照とDEFM](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L3180)、[文字列比較](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2054)。

## 7. 直接入力コマンドと利用範囲

共通の式評価を使うが、直接入力とプログラム中の命令受付は同一ではない。

| 書式・操作 | 直接入力側の処理 | プログラム側の処理 |
| --- | --- | --- |
| 数値式・変数参照 | 評価して結果を表示 | 変数から始まる経路はassignmentへ。他の一般式文の保証なし |
| 数値／文字列代入 | 代入と結果表示 | 代入処理あり |
| `RUN [数値式]` | 選択ページを実行。指定値を開始行の検索に使用 | RUNの実行caseなし |
| `LIST [行番号]` | PROでは指定番号以上の最初の行、指定なしで先頭。RUNではREADY表示 | LISTの実行caseなし |
| `CLEAR` / `CLEAR A` | PROで選択ページ／全ページを消去。RUNではERR2 | CLEARをVACと同じ変数消去として扱う |
| `VAC` | 変数を初期化 | 処理あり |
| `DEFM [追加数]` | 引数なしは総変数数表示。指定ありは確保と総数表示 | DEFMの実行caseなし |
| `SET E/F/N` | 表示設定を変更 | 処理あり |
| `SAVE [A]` | SAVEモードへ入りWaveOut.saveaを呼ぶ。SAVEとSAVE Aで出力経路を分けていない | SAVEの実行caseなし |
| `LOAD` | 受付分岐はあるが処理せず戻る。ファイル読込機能とは別 | LOADの実行caseなし |
| `BEEP [0/1]` | 音声処理へ渡す | 処理あり |
| `PRINT` / `INPUT` | sbCmdの対応caseなし。通常の直接コマンドとして使えるとはしない | 処理あり |
| `MODE` | 式としての直接入力はERR2 | 4=DEG、5=RAD、6=GRAD。7/8は何もしない分岐、その他はERR5 |

DEFMの引数分岐は、数値トークン開始なら整数として解析、変数開始なら式を評価する構成。任意の数値式を同じように受け付ける仕様ではない。RUN開始行とGOTO/GOSUBの数値整形も異なるため、小数や末尾0の付いた値の扱いは要確認。

根拠: [sbCmd](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L537)、[sbInterp](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L743)。

## 8. プログラム命令

| 代表書式 | 旧実装の動作 |
| --- | --- |
| `変数=式` | 数値／文字列を代入。添字付き領域も対象 |
| `PRINT ...` | 第9節参照 |
| `INPUT ["表示文字列",]変数[,変数...]` | 第9節参照 |
| `GOTO 数値式` | 小数を0方向へ切り捨てて行番号を検索。該当行なしはERR4 |
| `GOTO #数値式` | ページを読み替えて先頭から実行。10未満を検査するが、負数の検査は不足 |
| `GOSUB 数値式` / `GOSUB #数値式` | 現在ページと戻りpcをスタックへ保存して分岐 |
| `RETURN` | 保存したページ・pcへ戻る。スタックが空ならERR2 |
| `IF 条件 THEN 後続` | 条件が偽なら行末まで飛ぶ。真なら後続を処理 |
| `IF 条件;後続` | THENの代わりにセミコロンを受け付ける |
| `FOR 変数=初期値 TO 終値 [STEP 増分]` | 増分の既定値1。変数・終値・増分・戻り位置を保持。開始条件の不整合は第13節 |
| `NEXT 変数` | 対応変数を見つけるまでFORスタックをpop。変数を増分だけ更新し、終値を越えたら終了。それ以外は戻る |
| `STOP` | 実行をpause。EXEによる再開が可能 |
| `END` | 実行を終了 |
| `LET` | LET自体のcaseでは何もしない。後続の代入へ進む構成 |
| `REM` | 行末まで読み飛ばす |
| `ON 数値式 GOTO/GOSUB 宛先,...` | 選択値をint化し、1起点で宛先を選ぶ。0は命令を飛ばす。宛先列の範囲外処理は要検証 |
| `DATA 値,...` | 事前の行走査で収集。1行の先頭命令がDATAの場合を対象とする。最大512項目の仮上限 |
| `READ 変数,...` | DATAを順番に読んで代入。数値領域へはBigDecimal変換。未定義DATA等は不整合あり |
| `RESTORE [行番号]` | 引数なしはデータ位置を先頭へ、行番号ありはその行のDATA先頭へ。指定行が見つからなければERR4 |
| `VAC` / `CLEAR` | プログラム内では変数を初期化 |
| `SET 設定` / `BEEP [数値]` / `MODE 数値` | 表示、音、角度を設定する経路 |

### IF後続の判定

- 数値条件は0以外を真とする。文字列比較の経路もある。
- THEN後が数値または`#`ならGOTO相当。
- THEN後が変数なら次のトークンを見て分岐か後続処理かを判断する。単独変数の後が改行またはコロンの場合は分岐として処理する。
- THEN後の変数を含む複雑な式全体を、一般的なIF文法として定義し直さない。境界は旧版での確認が必要。
- 偽の場合はコロン以降を含め、その行の残りを飛ばす。

根拠: [分岐・IF](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1346)、[FOR〜RETURN](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1538)、[READ/DATA/RESTORE](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L904)。

## 9. PRINT・INPUT・LCD・キー

### PRINTとCSR

- 文字列、文字列変数・文字列関数、数値式、CSR指定を受け付ける。
- 非負の数値には先頭空白を付けて表示する。
- `;`は要素の連結に使う。末尾`;`の有無も、表示後にpauseするかに関係する。
- `,`は表示後にpauseし、再開後に残りのPRINT要素を処理するための状態を保持する。
- PRINTの内容が空なら保持文字列を消去する。何もないPRINTの表示・継続条件も専用処理に従う。
- `CSR 数値式`は0〜11を受け付け、その位置から出力用文字列を置換する。範囲外はERR5。
- CSRはPRINT要素として処理され、単独コマンドとしての実行caseはない。

### LCD

- 12文字を表示する。固定キャラクタを描く方式で、BASICによる自由なグラフィック命令はない。
- bprintによる長文表示は12文字超で自動スクロール。最初に800ms待ち、その後300msごとに1文字ずつ送る。
- この時間は旧版の設定値であり、実機の計測値と断定しない。
- 入力バッファは128要素。文字入力は127未満を条件とする。実機の行長上限と同一の仕様とは扱わない。

### INPUT

- 表示プロンプトに`?`を付け、入力を待つ。複数変数と個別の表示文字列を扱う経路がある。
- 数値入力はBigDecimalへ直接変換し、式として評価しない。変換できなければERR2。
- 文字列はA$等が7文字、`$`が30文字を検査する。
- 空文字は完了条件にならず、待ち続ける。
- 入力は共有inTextを50ms間隔で監視。強制終了またはpauseにより待機を抜ける。後者の継続動作は要確認。

### KEY

数値の文脈では押下コード、文字列の文脈では対応する1文字を返す。未押下はそれぞれ0、空文字。複数押下ではボタン状態配列の先頭側を優先し、通常面のキーコードを使う。Shift等の編集入力の変換とは別処理。

根拠: [PRINT](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1144)、[INPUT](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L1617)、[LCD](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/Lcd.java#L271)、[Keyboard](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/Keyboard.java#L47)。

## 10. 関数

数学関数の`x`は数値引数。括弧なし引数の取り込み範囲は表の評価層を参照する。単純に全てを「次の式全体」としない。

| 関数 | 処理・返り値 | 引数を読む層／制約 |
| --- | --- | --- |
| SIN / COS / TAN | 三角関数。現在の角度単位で処理 | evalExp5。特定の角度で0へ補正する分岐あり |
| ASN / ACS / ATN | 逆三角関数。現在の角度単位で結果を返す | evalExp5 |
| LOG / LN | 常用対数／自然対数 | evalExp6 |
| EXP | 指数関数 | evalExp5 |
| SQR | 平方根 | evalExp6 |
| ABS | 絶対値 | evalExp5、BigDecimal |
| SGN | 負=-1、0=0、正=1 | evalExp5 |
| INT | 負の無限大側への整数化 | evalExp5。負数はUP、非負はDOWN |
| FRAC | 1で割った剰余 | evalExp5。負数の符号も旧コードのremainderに従う |
| RND | 第2引数nからscale=-n-1を求めてHALF_UP | 第1・第2引数はevalExp5。nはint化して-99〜99を検査。区切りの厳密な検査は不十分 |
| RAN# | Math.random由来の値 | 引数なし |
| PI / PI記号 | Math.PI由来の値 | 引数なし |
| KEY / KEY$ | 数値または文字列のキー入力 | 引数なし。文脈依存 |
| LEN(文字列) | 文字列長 | 引数は引用文字列または文字列変数経路。閉じ括弧を要求 |
| VAL(文字列) | 数値へ変換 | 先頭の連続数字があればそこだけを抽出して変換。それ以外は全体をBigDecimalへ渡す |
| MID(開始[,長さ]) / MID$ | 独立文字列`$`の部分文字列 | 開始は1起点。引数はint化。範囲外・長さ不正は空文字の分岐 |
| STR$(数値式) | BigDecimal値をString.valueOfで文字列化 | LCDの数値整形とは別。先頭トークンの種別検査があり、単項符号開始等は要確認 |

- LEN/VAL等での式の受付範囲は経路に依存する。一般的なBASICの同名関数から拡大解釈しない。
- VALは例えば正数の小数表現では先頭整数部分を抽出する構造だが、負号で始まる文字列には同じ正規表現が一致しない。意図した仕様か不具合かは未決。
- MID$はMIDと同じ処理であり、一般的な`MID$(任意文字列,開始,長さ)`ではない。
- Commonの切り出し表とkwTableに差があり、RNDやPI等の空白なし表記には確認が必要。

根拠: [数値関数](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2641)、[文字列関数](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L2205)。

## 11. 実行状態・停止・速度

- RUNは選択ページのソースを読み、ラベル表を作り直す。変数を自動でVACする処理ではない。
- GOSUBの保存状態はページとpc。FORは変数番号、終値、増分、戻りpc。
- STOP文とPRINT後の待機はpauseを立て、実行ループが200ms間隔で解除を待つ。
- EXEでpauseを解除して同じ実行を続ける。
- STOPキーはforcedExitを立てる終了要求。STOP文のpauseとは異なり、再開用のデバッガ停止ではない。
- END、終端への到達、強制終了、InterpreterExceptionで実行を終える経路がある。
- RUN開始でFOR/GOSUBスタックを明示的に初期化していないため、異常・途中終了後の再RUNは要確認。
- 処理速度はインタープリタのループを数回進めてから経過時間を測り、設定に応じて待つ。数学関数に追加の20ms待ちがあるものもある。
- これはBASIC処理速度の調整であり、CPU命令のサイクル再現ではない。LCDスクロールの待ち時間は別に固定されている。
- 命令単位ステップ実行、ブレークポイント、変数変更API、実行履歴の巻き戻しは旧版の仕様に含まれない。

根拠: [RUNと実行ループ](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L468)、[停止・再開](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/PbMain.java#L282)、[EXE/STOPキー](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/Lcd.java#L390)。

## 12. 容量計数・エラー

### 容量

- プログラム1行は、本文の計数＋3ステップ。
- 本文では空白・タブを原則無視し、予約語は原則1、通常文字は文字数として計数。引用内の文字列は引用符を含む文字数分。
- LEN/VAL/MIDは括弧込み予約語に合わせる補正を持つ。
- 全ページの行容量を加え、DEFMの追加数×8を加算する。
- 総容量は544または1,568。残量は負数なら0として表示する。
- プログラムの追加・実行時に、この残量を使って容量超過を拒否する処理は調査経路で確認できない。DEFM追加数の上限検査はある。
- READMEに実機との差が既知である旨があり、上記は旧版の概算方法として扱う。

### エラー

| 番号 | 分類 |
| --- | --- |
| ERR0 | System error |
| ERR1 | Memory overflow |
| ERR2 | Syntax error |
| ERR3 | Mathematical error |
| ERR4 | Undefined line number |
| ERR5 | Argument error |
| ERR6 | Variable error |
| ERR7 | Nesting error |
| ERR9 | Option error |

列挙されている番号と、実際に投げる処理は区別する。ERR8はdummy。エラー時は該当位置から行を探索し、可能なら`ERR番号 Pページ-行番号`を表示して例外を投げる。配列境界や数値例外など全てがこのエラー体系へ変換されるわけではない。

根拠: [本文の容量](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L3495)、[エラー](https://github.com/digihori/pokecom2/blob/9deb46a3c37c6cc2ae860cfc42df4297a4cf3988/app/src/main/java/tk/horiuchi/pokecom2/SBasic.java#L3606)。

## 13. 実装上の不整合と新版での扱い

以下を正常な言語仕様として固定しない。現時点ではコード上の確認までで、実行再現は未実施。

| 項目 | 旧コードの状態 | 新版への扱い |
| --- | --- | --- |
| FORの開始条件 | 初期値を代入した変数と、その初期値を比較し、終値との比較になっていない | 正しい開始条件を採用仕様として定義する |
| STEP 0 | BigDecimalへequals(0)でIntegerと比較する検査 | 0の扱いを定義し、型に適した判定にする |
| 実行スタック | RUN開始時のFOR/GOSUBスタック消去がない | 新規RUNと再開の初期化条件を分ける |
| 配列・ページ | 負数の検査不足、文字列側の上限条件のずれ | 不正アクセスをPBエラーへ変換する条件を定義 |
| 巻き戻し位置 | putBackが変換後トークン長を使う | 原文位置を保持し、長さ変換で位置がずれないようにする |
| 引用文字列 | 未閉鎖時や終端で境界に問題があり得る | 省略可否と入力終端を定義 |
| INPUT空文字・停止 | 空文字が完了にならず、pauseで待機を抜ける | 空入力と中断・再開を明示的に定義 |
| DATA/READ | DATAなしでのnull、READがコロンでループを抜けない構造、`$`の長さ検査に行番号部分を含む箇所 | 拡張採否と正常動作を別途定義 |
| VAL | 正負や小数で数値変換が非対称 | 旧版再現か修正かを決める |
| 予約語の表 | 切り出し表・検索表・PB変換表が一致しない | 認識・実行・容量・転送の対応を一元的に管理する案 |
| 内部コード | VAR/VER等、Perl版と差がある | エスケープ基準はPerl版を維持し、予約語は別途分類 |
| 固定配列 | 実行・読込・保存・音声変換に仮サイズ | 実機容量と実装資源上限を分ける |

## 14. 新版の採用仕様へ反映する順序

本書を起点として、次の3区分で判断する。

1. **継承する言語動作の候補**: PB独特の省略記法、変数領域、文字列、ページ、IF・FOR・GOSUB、PRINT/CSR、KEY。
2. **旧版の追加機能・拡張の採否**: `%`、LET/REM/ON/READ/DATA/RESTORE/STR$/MID$/BEEP等。存在は確認できるが、PB-100標準として一括採用しない。
3. **修正・再設計する動作**: 第13節の不整合、命令単位デバッグ、状態変更、UI非依存化、正確な容量判定。

マニュアル・実機は、この基準仕様の不明点や差異を確認するために使う。全項目の実機確認が終わるまで、文法・実行状態・アーキテクチャの設計を停止する進め方にはしない。

今後の確認例は、通常形だけでなく、空白・括弧省略、複数命令、正負数・べき乗、文字列境界、FORの開始条件、STOP文とキー、12/13文字、容量とDEFMを含める。旧版の実行結果を記録した際は、静的な読解結果と分けて追記する。
