# HorrorMaker

SwiftUIのiOSアプリです。Geminiによる怪談の生成・調整と音声生成、効果音を組み合わせた再生、作品のローカル保存、StoreKitの購入処理を含みます。

## 起動

1. iOS 26.1以降のSDKに対応するXcodeで `HorrorMaker.xcodeproj` を開きます。
2. Signing & Capabilitiesで自分のTeamを設定します。必要に応じてBundle Identifierを変更してください。
3. Edit Scheme → Run → Arguments → Environment Variablesで `GEMINI_API_KEY` を設定します。共有Schemeへ保存しないでください。
4. HorrorMakerターゲットを実行します。

`.env.example` は必要な変数名の見本です。`.env.local` はGitから除外しますが、アプリはこのファイルを自動で読みません。Xcodeの実行時環境変数に設定してください。キーがない場合は生成機能がエラーを表示します。

## キーと個人情報

APIキーをSwiftソース、共有Scheme、READMEやスクリーンショットへ書かないでください。プロンプト・生成した作品はGeminiへ送信されるため、氏名、住所、連絡先などを入力しないでください。作品ライブラリは端末のUserDefaultsに保存されます。個人の作品やログをGitへ追加する場合は内容を確認し、通常は `private-data/` または `exports/` に保存してください。

実行時環境変数は開発用です。配布アプリから秘密キーを安全に保持する仕組みではありません。配布時は認証付きのサーバー経由でAPIを呼び出す構成にしてください。

## 購入の確認

ローカルの購入動作を確認する場合はSchemeのStoreKit Configurationで `HorrorMaker.storekit` を指定します。実際の販売にはApp Store Connect側の製品設定も必要です。
