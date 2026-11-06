package pdfview;

/**
	What `pdfview.PdfView.show()` shows a PDF in: anything that goes to a URL and
	shows HTML. StageWebView's `webview.WebView` and Lime's `lime.ui.WebView` both
	are, as they stand. OpenFL's `openfl.media.StageWebView` names the two
	differently; wrap one in `pdfview.openfl.StageWebViewTarget`.

	A structure rather than a type that names any webview, so showing a PDF compiles
	in no webview a program does not use. Naming StageWebView's own `WebView` here
	would build its native backend, which on Linux links WebKitGTK, into a program
	that shows its pages through Lime's.

	`PdfView.release()` finds the page it wrote by the target object itself, so pass
	the same object to both.
**/
typedef PdfTarget =
{
	/** Goes to a URL. **/
	function load(url:String):Void;

	/** Shows HTML as a page of its own. **/
	function loadHTML(html:String):Void;
}
