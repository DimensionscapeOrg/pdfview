package pdfview.openfl;

import openfl.media.StageWebView;

/**
	An `openfl.media.StageWebView` as a `pdfview.PdfTarget`: its `loadURL` and
	`loadString` under the names `PdfView.show()` calls.

	A module of its own, so only a program that imports it compiles in the
	facade. Keep the one wrapper for a view and pass it to both `PdfView.show()`
	and `PdfView.release()`, which finds the page it wrote by the wrapper.
**/
class StageWebViewTarget
{
	/** The facade this shows PDFs in. **/
	public var view(default, null):StageWebView;

	public function new(view:StageWebView)
	{
		this.view = view;
	}

	/** Goes to a URL. **/
	public function load(url:String):Void
	{
		view.loadURL(url);
	}

	/** Shows HTML as a page of its own. **/
	public function loadHTML(html:String):Void
	{
		view.loadString(html);
	}
}
