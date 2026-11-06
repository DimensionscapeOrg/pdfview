package pdfview;

/**
	What `pdfview.PdfView.show()` shows a PDF in: a `webview.WebView`, or with
	OpenFL, an `openfl.media.StageWebView`. Either converts implicitly.
**/
abstract PdfTarget(PdfTargetData)
{
	inline function new(data:PdfTargetData)
	{
		this = data;
	}

	/** The webview itself, which keys the viewer page `PdfView.release()` removes. **/
	public var view(get, never):{};

	/**
		A target made of its two operations, for a host that wraps a webview of its
		own. `view` is any object that stays the same for the one webview.
	**/
	public static function of(view:{}, load:String->Void, loadHTML:String->Void):PdfTarget
	{
		return new PdfTarget({view: view, load: load, loadHTML: loadHTML});
	}

	@:from public static function fromWebView(view:webview.WebView):PdfTarget
	{
		return new PdfTarget({view: view, load: view.load, loadHTML: view.loadHTML});
	}

	#if openfl
	@:from public static function fromStageWebView(view:openfl.media.StageWebView):PdfTarget
	{
		return new PdfTarget({view: view, load: view.loadURL, loadHTML: function(html:String):Void view.loadString(html)});
	}
	#end

	/** Navigates to a URL. **/
	public inline function load(url:String):Void
	{
		this.load(url);
	}

	/** Shows HTML as a page of its own. **/
	public inline function loadHTML(html:String):Void
	{
		this.loadHTML(html);
	}

	inline function get_view():{}
	{
		return this.view;
	}
}

@:noCompletion
typedef PdfTargetData =
{
	var view:{};
	var load:String->Void;
	var loadHTML:String->Void;
}
