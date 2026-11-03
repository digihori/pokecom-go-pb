# 技術選定 第2段階 — 実行制御・保存・周辺連携

作成日: 2026-11-03

KMP＋Composeを前提に、基本設計を実現する方式を選ぶ。選定は設計上の採用方針であり、依存の導入・版固定・試作・実機検証はまだ行っていない。

参照: [主要技術の選定](technology-selection.md)、[基本設計](basic-design.md)、[要求仕様](requirements.md)。

## 1. 今回の選定結果

| 対象 | 採用方針 | 適用範囲 |
| --- | --- | --- |
| 文法解析 | 共通Kotlinの手書き字句解析＋再帰下降構文解析 | PB省略記法・式・命令・原文対応 |
| 実行形式 | 式の構造と命令列を保持するインタープリタ | JIT・ネイティブコード生成は採用しない |
| 非同期制御 | kotlinx.coroutines＋Channelを使う単一のセッション処理ループ | pb-session。Coreの式評価自体は通常の同期処理 |
| UI状態通知 | 読取専用StateFlow＋不変の画面状態 | 最新のLCD・実行状態・観察用データ |
| 必須要求・完了応答 | 要求ID付き状態＋操作ごとの結果応答 | INPUT、ステップ完了、ソース変更等。StateFlowだけに依存しない |
| 共通データの保存・交換 | kotlinx.serializationのJSON | 設定、メタ情報、外部連携DTO。BASICソース本文は別 |
| BASIC保存 | 旧形式を継承したページ指定付きテキスト | エスケープを共通定義で処理 |
| LCD描画 | Compose Canvasと固定キャラクタデータ | 12セルの描画。スクロールの意味はセッション側 |
| 日本語／英語 | Compose Multiplatform resources | 診断コードとUI翻訳を分離 |
| QR生成 | JVM版ZXing core | 最初はデスクトップでのQR出力 |
| AndroidのQR読取 | CameraX＋ML Kitのモデル同梱版 | Playerのカメラ接続。共通BASICには依存させない |
| iOSのQR読取 | OSのバーコード読取APIを使う接続層 | 具体API・最小OS版はPlayerの設計時に固定 |
| WAV変換・信号解析 | 共通KotlinのPB専用処理 | PCM読書き、PBフレーム・トークン、診断位置 |
| MCP | 公式Kotlin SDKのJVMサーバー、Streamable HTTPを第一方式 | デスクトップの同じ開発支援サービスへ接続 |
| 仕様試験 | kotlin.test＋kotlinx-coroutines-test | 共通仕様・仮想時間・入力列による再現試験 |

数値ライブラリは前段階の第一評価候補を維持する。本書によってionspinの本採用や、数学関数の全方式を確定するものではない。

## 2. 解析器・実行形式

### 選定理由

旧SBasicの再帰下降方式を参考にするが、解析と実行を分け、トークンの開始・終了位置を保持する。PB固有の空白・括弧省略、IFの後続処理、文字と命令区切りを直接扱えるようにする。

汎用パーサー生成器は初期構成に入れない。独特の省略と原文対応に合わせて規則を追いやすい手書き方式を選ぶ。この判断は一般的なパーサー生成器の優劣ではなく、今回の言語規模と読解用途に対する選択。

- 式は構造として保持し、命令はページ・行・行内位置・原文範囲へ対応させる。
- 数値・文字列の式評価を直接入力とプログラムで共有する。
- PRINT/INPUT等の途中待機は、評価済み部分を継続状態として持つ。
- 到達しない行の構文エラーをいつ扱うかは、解析方式と分けて互換仕様として決める。
- デバッグ向けの命令分解により、実機向けコードや容量の算定元を書き換えない。

根拠となる旧実装・未確認点は [BASIC詳細仕様](basic-specification.md)を参照する。

## 3. Coroutinesによるセッション制御

### 実行の所有者

実行状態を書き換える主体は、1セッションにつき1つの処理ループとする。操作をChannelへ送り、ループ内で順に処理する。UI、MCP、キー、タイマーがCoreを直接呼ばない。

Coroutinesを使うだけでは共有状態は安全にならない。構造化した並行処理と状態の所有を明示する。[Kotlinの共有状態・並行処理](https://kotlinlang.org/docs/shared-mutable-state-and-concurrency.html)

### 応答性

- Coreは一定量の内部処理で戻る。セッションはその間に操作を取り込む。
- 実行を進める際にUIスレッドを占有しない。Dispatchers.Default等を使う方針だが、1セッションの状態更新は並列化しない。
- 新しいコルーチンを命令ごとに起動しない。深い式評価でsuspendやdelayを繰り返す設計にもせず、Coreの中断・継続境界を明確にする。
- INPUT待ちや表示待ちの間、処理ループを入力値の到着待ちで塞がない。待機状態を設定して、他の操作を受け付ける。
- Channelの容量は有限にする。終了・停止要求は命令境界ごとに確認し、保留キー等の列の後ろで長時間待たせない。上限値・優先処理の詳細は評価時に決める。
- 速度調整用の待ちと、入力・停止要求は待機を切り替えられる構造にする。
- コルーチンのキャンセルとBASICのSTOP文は別。セッション破棄はスコープの終了、BASICの中断終了は明示操作で扱う。

### 状態とイベントの違い

StateFlowは最新状態の通知に使う。公式APIでは値が合流され、遅い購読者は途中の更新を飛ばし得る。[StateFlowの仕様](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.flow/-state-flow/)

そのため、全命令履歴・入力要求・変更確定通知をStateFlowの更新だけで表現しない。

- 入力要求は要求IDとともに状態へ保持し、解決するまで残す。
- 各操作は操作IDに対応する結果を返す。命令単位実行は対象の完了結果・状態版を受け取れるようにする。
- 実行中の画面更新はまとめてもよいが、停止直後の状態と完了応答は確定してから返す。
- 観察用スナップショットを不変にし、共有された可変配列をUIへ渡さない。
- UIの一時非表示・再購読でも、入力待ちやエラー状態を再取得できる。

## 4. Composeの状態管理・描画

大きな状態管理フレームワークやDIコンテナを最初から加えず、セッション操作、画面用状態、環境接続をコンストラクタ等で組み合わせる。

LCDは固定字形の点データをCanvasで描く。BASICに任意ドット描画や独自キャラ定義を追加する意味ではない。字形・12セル・カーソル等のデータを共通化し、デスクトップの周辺画面とPlayerの本体画面は分ける。

日英UIはComposeの共通リソースに集約する。任意の言語へその場で切り替える動作と、OSに従う初期言語をアプリ設定として区別する。診断の分類と引数は言語非依存とし、PBプログラム内の文字列を翻訳しない。[Compose resources](https://kotlinlang.org/docs/multiplatform/compose-multiplatform-resources.html)

## 5. 保存・設定・ファイルアクセス

### データ形式

- BASICは通常のテキストで保存・取込する。旧ページ指定と特殊記号の定義を継承する。
- 設定や作品の付加情報は、版番号付きのJSONを基本とする。初回に専用データベースを必須としない。
- JSONにはkotlinx.serializationを使う。公式資料ではJVM・Native等に対応し、JSON形式はStableとされる。[Kotlin Serialization](https://kotlinlang.org/docs/serialization.html)
- 任意精度の数値をJSONへ出す場合は、十進文字列で値を表す。JSONの数値をDoubleとして読み直す経路を避ける。
- 実行状態全体の永続化や復元は採用しない。将来必要になった場合は、現在の表示用DTOとは別の保存契約を設計する。

### OS接続

共通部分へファイルパスを直接渡す前提にせず、取得したテキスト／バイト列と読込元の識別情報を渡す。

- デスクトップ: JVM側のファイルAPIとシステムダイアログ接続。最初は明示的な読込を基本設計案とする。
- Android: Storage Access Frameworkを使い、選択した文書のURIから読み書きする。[Android公式資料](https://developer.android.com/training/data-storage/shared/documents-files)
- iOS: システムの文書選択・共有機能を接続する。長期アクセス権やファイルの所有を含む詳細はPlayer設計で固定する。

外部エディタの変更は「ディスク上の変更」として通知可能にし、実行中のソース版を無条件に入れ替えない。自動読込の採否は引き続き後で判断する。

## 6. QR生成と読取

### 共通にする範囲

PBのソースを転送するデータ形式、形式の版、対象・容量判定、受信後の検証は共通Kotlinで扱う。QRの画像認識やカメラは共有BASICから分離する。

現段階ではバイナリ圧縮・分割QR・最大作品サイズまで確定しない。各OSから同じ文字列を受け取れるテキスト形式を第一案とし、必要ならバイナリの文字列表現を検討する。URLのみを渡す方式へ変更しない。

### 生成

初回の出力先はデスクトップなので、JVM版ZXing coreを使う。多機種対応を理由に、未使用のモバイル向けQR生成依存まで追加しない。共通の転送データを画像化する部分だけがJVM依存となる。[ZXing QRCodeWriterの実装](https://github.com/zxing/zxing/blob/master/core/src/main/java/com/google/zxing/qrcode/QRCodeWriter.java)

### 読取

AndroidはCameraXとML Kitのモデル同梱版を選ぶ。初回スキャン前のモデルダウンロードを待つ方式を第一案にしない。公式資料で同梱／動的ダウンロードの差が説明されている。[ML Kit Barcode Scanning](https://developers.google.com/ml-kit/vision/barcode-scanning/android)、[CameraXとの連携](https://developer.android.com/media/camera/camerax/mlkitanalyzer)

iOSはOSの読取APIを使う方針で、VisionのVNDetectBarcodesRequest等を候補とする。カメラプレビュー・撮像・Composeとの接続、採用APIと最低OS版はPlayer着手前に具体化する。Appleの詳細ページは自動取得で本文を確認できなかったため、今回iOS APIの厳密な採用版は確定しない。[Apple公式の対象API](https://developer.apple.com/documentation/vision/vndetectbarcodesrequest)

QRは読み取ってソースを確認・取り込む操作とし、自動実行はしない案とする。受信した容量超過・未知文字・未対応形式は共通の適合確認で扱う。

## 7. WAV・波形解析

PBの信号・フレーム・文字・予約語変換は、既存のPerl版とWaveOutを基準に共通Kotlinで実装する。BASIC実行基盤に音声ライブラリを組み込まない。

- 最初は非圧縮PCMのRIFF/WAVEを対象とする案。出力は既存スクリプトに合わせた22,050Hz・8bit・モノラルを第一候補にする。
- WAVを読む処理、音声をサンプル列へ正規化する処理、PB信号を復号する処理を分ける。
- 元サンプル位置→信号区間→ビット→バイト→PBデータの対応を保持し、失敗箇所を波形画面で示せるようにする。
- 再生・録音は環境接続で行う。Playerへカセット機能を加える設計ではない。
- 波形は必要な区間だけを縮約して描き、録音の全サンプルをComposeの個々の状態として持たない。
- まず既存の成功WAVと新規生成WAVを扱い、録音WAVへの耐性は後続で広げる。入出力のbit深度・ch数・周波数の受入範囲はWAV詳細設計で決める。

音声一般の形式変換やFFT等のライブラリは、対応範囲が決まるまで追加しない。既存Studioと同程度の波形解析という要求は維持し、画面と機能一覧の確認を別作業として残す。

## 8. MCP接続

### SDKと構成

デスクトップ/JVM側で公式Kotlin SDKを使う方針とする。KMPコアからSDKへ依存せず、MCPツールの実装は既存の開発支援操作へ変換する。TypeScriptやPythonのランタイムを初期構成の必須依存に増やさない。[公式Kotlin SDK](https://github.com/modelcontextprotocol/kotlin-sdk)

SDKの公式Tierは、プロトコル対応や保守の評価と別途確認する。採用するSDK版と接続先AIクライアントで必要な操作が通ることは、MCP機能の着手時に検証する。公式SDKであることを、全クライアントとの動作保証とは扱わない。[公式SDK一覧](https://modelcontextprotocol.io/docs/sdk)

### 第一の接続方式

起動済みデスクトップの同じセッションを操作するため、Streamable HTTPのローカルサーバーを第一方式とする。Kotlin SDKとKtorの対応するサーバー機能を利用し、プロトコル自体は独自実装しない。

- 初期はlocalhost限定。機能を有効にした際に起動し、外部ネットワークへ公開しない。
- Origin検査と認証を含む接続仕様を設計する。具体的なポート・認証情報の渡し方は、クライアント設定と合わせて決める。
- UI操作とMCP操作は同じセッション処理列を通し、実行ID・状態版を検査する。
- 解析・生成候補の取得から段階導入し、ソース変更や実行を公開する際も操作契約を共通化する。
- SDKを使っても、変更する実行版とAIが参照した版の食い違いはアプリ側で検出する。

この方式は、クライアントがサーバーを子プロセスとして起動するstdioとは起動・接続の形が異なる。stdio専用クライアントへの対応が必要なら、同じアプリへ接続する小さな橋渡しプロセスを後続で検討する。クライアントごとに別の実行状態を勝手に作らない。

MCPの標準はstdioとStreamable HTTPを定義し、ローカルHTTPにはOrigin検査等の要件・推奨がある。[MCP transport仕様](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)

## 9. 検証と導入順序

選定結果の検証は、実装に進む段階で実施する。

1. 数値評価候補とiOS共通コードのビルド可能性を先に確認する。
2. パーサーの原文対応と、命令単位実行の最小経路を確認する。
3. Channelによる操作列、待機・停止・再RUN、StateFlowの再購読を確認する。
4. 共通のテキスト・設定保存、LCDと日英UIを追加する。
5. WAV、QR、MCPは各機能を実装する段階で依存を追加する。全部を初回の骨組みに入れない。

共通試験にはkotlin.test、待機・時間の検証にはkotlinx-coroutines-testを使う。後者には仮想時間を扱うTestCoroutineScheduler等がある。BASIC自身の時計も同じ試験時間へ接続し、実時間を長く待つ試験を避ける。[公式coroutines-test API](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/)

数値・PB仕様・パーサーはUIなしで試験する。端末のカメラやファイル権限等は環境別に確認する。

## 10. 今回残す未決事項

- 数値ライブラリの本採用とPB数値精度、数学関数の方式。
- Kotlin・Compose・Gradle等の評価開始版は[評価計画](version-and-foundation-evaluation.md)へ具体化。本採用の版固定と製品の最低OS版は評価後に決める。
- iOSのQR読取API・カメラ接続の最終選択。
- QRの容量・分割・圧縮、WAV入力の対応品質、既存Studioとの機能対応。
- Logical/PhysicalキーのOS別対応とコントローラの接続方式。
- MCP対象クライアント、認証・起動・設定の詳細、stdio互換の必要性。

後続機能の方式を選んだことは、初回リリースへ追加する決定ではない。版固定・ライセンス確認・接続試験を経て導入し、必要なら選定を更新する。
