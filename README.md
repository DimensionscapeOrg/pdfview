# pdfview

Shows PDFs in a webview on every platform [StageWebView](https://github.com/DimensionscapeOrg/stagewebview) supports: StageWebView's own `WebView`, Lime's `lime.ui.WebView`, which draws with StageWebView's engines, or OpenFL's `StageWebView` facade.

WebView2 and WKWebView display a PDF themselves. Android WebView has no PDF viewer, and WebKitGTK has one only when the distribution built it in, so on Linux and Android pdfview renders the file with a bundled [PDF.js](https://github.com/mozilla/pdf.js) instead.

| Platform | Webview | `AUTO` shows the PDF with |
| --- | --- | --- |
| Windows | WebView2 | WebView2's own viewer |
| macOS, iOS | WKWebView | WKWebView's own viewer |
| Linux | WebKitGTK | the bundled PDF.js |
| Android | Android WebView | the bundled PDF.js |

StageWebView left PDF viewing out on purpose: a webview library should not carry a few megabytes of somebody else's JavaScript for the programs that never show a PDF. pdfview is the piece a program that does show them adds.

## Installing

```
haxelib install pdfview
```

Then add it next to StageWebView: `-lib pdfview` in an hxml file, or `<haxelib name="pdfview" />` in an OpenFL or Lime project. It needs StageWebView 1.0.1 or later.

## Use

```haxe
import pdfview.PdfView;

PdfView.show(webView, "report.pdf");
```

`webView` is anything with `load(url)` and `loadHTML(html)`: a `webview.WebView`, a `lime.ui.WebView`, or a webview of a host's own. `PdfTarget` is that structure and names no webview class, so showing a PDF compiles in no webview a program does not use; above all, a program on Lime's `WebView` does not build StageWebView's own backend, which on Linux links WebKitGTK. OpenFL's `openfl.media.StageWebView` calls the two `loadURL` and `loadString`, so wrap it once in a `pdfview.openfl.StageWebViewTarget` and pass the wrapper.

`show()` takes a third argument, a `PdfViewer`:

- `AUTO` (the default): the webview's own viewer where it has one, the bundled one elsewhere
- `NATIVE`: always navigate to the file
- `BUNDLED`: always the bundled PDF.js

When the bundled viewer is used, the document is drawn page by page onto canvases and the page's root element gets a `data-pages` attribute with the page count once every page is drawn, which a program or a test can read with `evaluateJavaScript`.

### Releasing the viewer page

On Windows the bundled viewer's page is larger than WebView2 accepts as a string (2 MB), so `show()` writes it to a file in `TEMP` and navigates to that. The file holds the document, so call `PdfView.release(webView)` when the webview is done with it, for instance before disposing it. `release()` is safe to call when there is nothing to release, and showing a PDF with the native viewer releases the page on its own.

## Size

PDF.js is about 1.8 MB of script. It is compiled in, as two Haxe resources, only where it is needed: on Linux and Android, or anywhere with `-D pdfview_pdfjs` (which `BUNDLED` needs on Windows, macOS and iOS). `PdfView.isBundled` says whether it is in.

## Updating PDF.js

`assets/pdfjs` is PDF.js 4.10.38's legacy build, with each file's closing `export{...}` rewritten into a global so the viewer runs inline, with no file access and no Web Worker. `build/PdfJsBundle.hx` makes it from a pdfjs-dist package:

```
npm pack pdfjs-dist@4.10.38
tar -xzf pdfjs-dist-4.10.38.tgz -C <dir>
haxe -cp build --run PdfJsBundle <dir>/package
```

## Releasing

`powershell -File build/release.ps1` packs `bin/pdfview-<version>.zip` from the files git tracks at HEAD and prints the `haxelib submit` command for it; `-Submit` runs it too.

## Tests

From the repository root, with a project-local repository holding StageWebView, hxcpp and utest:

| Command | What it checks |
| --- | --- |
| `haxe build/tests.hxml` | which viewer `show()` picks, the file URLs it builds, the page it writes and `release()`, with no webview |
| `haxe build/native.hxml` then `bin/native/NativeMain bundled` | a two-page PDF printed by the webview, shown with the bundled viewer in a real hidden webview, every page drawn |
| `bin/native/NativeMain auto` | the same with `AUTO`: the webview's own viewer where there is one |
| `haxe build/no-webview.hxml` | a program that shows a PDF and names no webview compiles in no StageWebView or OpenFL module |

On Windows add `-D HXCPP_M64` to the native build. On Linux the native test needs a display (`xvfb-run` works) and GTK 3 and WebKitGTK 4.1 development files. hxcpp resolves StageWebView's native build files from its own working directory, so set `HAXELIB_PATH` to the project-local repository when building, or it may take them from somewhere else.

CI runs both on Windows and Linux. Android and the Apple platforms are not run in CI.

## License

Apache License 2.0. PDF.js is the Mozilla Foundation's, under the Apache License 2.0 too; see NOTICE.
