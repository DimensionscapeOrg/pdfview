package pdfview;

/**
	Selects how `pdfview.PdfView.show()` shows a PDF.
**/
enum abstract PdfViewer(Int) from Int to Int
{
	/**
		The webview's own viewer where it has one (WebView2 on Windows, WKWebView
		on macOS and iOS), the bundled PDF.js viewer elsewhere (Linux and Android).
	**/
	var AUTO = 0;

	/** Always navigate to the file and let the webview show it. **/
	var NATIVE = 1;

	/**
		Always use the bundled PDF.js viewer, rendered inline from the file's
		bytes. Bundled automatically on Linux and Android; elsewhere compile with
		`-D pdfview_pdfjs` to include it.
	**/
	var BUNDLED = 2;
}
