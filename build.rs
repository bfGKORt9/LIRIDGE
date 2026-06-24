fn main() {
    // flutter_rust_bridge v2 のビルドプロセスをトリガー
    // これにより、src/lib.rs の関数定義が変更された際に
    // Dart側のコードが自動的に再生成される基盤が整う
    flutter_rust_bridge_codegen::utils::build_in_main();
}
