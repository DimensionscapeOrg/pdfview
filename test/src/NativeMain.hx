import haxe.Timer;
import pdfview.PdfView;
import pdfview.PdfViewer;
import webview.WebView;

/**
	Shows a real PDF in a real, hidden webview and waits for every page to be drawn.

	Prints a two page document with the webview's own print engine, shows it with
	`PdfView.show()` and reads the page count the bundled viewer leaves on the root
	element. Exits 0 when it is 2, 1 otherwise. Run from the repository root:
	`NativeMain [auto|bundled]`, `bundled` by default. On Linux it needs a display
	(`xvfb-run` works).
**/
class NativeMain
{
	static inline final TIMEOUT_SECONDS:Float = 60;

	static function main()
	{
		final viewer:PdfViewer = Sys.args().indexOf("auto") >= 0 ? AUTO : BUNDLED;
		final dir = haxe.io.Path.join([Sys.getCwd(), "bin", "native-out"]);
		if (!sys.FileSystem.exists(dir))
		{
			sys.FileSystem.createDirectory(dir);
		}
		final path = haxe.io.Path.join([dir, "two pages.pdf"]);
		if (sys.FileSystem.exists(path))
		{
			sys.FileSystem.deleteFile(path);
		}

		final webView = new WebView(null, {hidden: true});
		webView.onError = message -> Sys.println("error: " + message);

		var printed:Null<Bool> = null;
		var loaded = false;
		webView.onLoad = () -> loaded = true;
		webView.loadHTML("<!doctype html><html><body><h1>Page one</h1>"
			+ "<h1 style=\"page-break-before: always\">Page two</h1></body></html>");
		pump(() -> loaded);
		webView.printToPDF(path, null, (success, error) ->
		{
			if (!success)
			{
				Sys.println("print failed: " + error);
			}
			printed = success;
		});
		pump(() -> printed != null);
		if (printed != true)
		{
			finish(webView, 1, "the document was not printed");
		}

		Sys.println("viewer: " + (viewer == AUTO ? "auto" : "bundled") + ", native viewer here: " + PdfView.hasNativeViewer
			+ ", bundled compiled in: " + PdfView.isBundled);
		PdfView.show(webView, path, viewer);
		if (viewer == AUTO && PdfView.hasNativeViewer)
		{
			// The webview's own viewer leaves nothing to count, but the document it shows is the PDF.
			final type = poll(webView, "document.contentType", value -> value == "\"application/pdf\"");
			finish(webView, type == "\"application/pdf\"" ? 0 : 1, "native: the page is " + type);
		}

		final pages = poll(webView, "document.documentElement.getAttribute('data-pages') + '|'"
			+ " + (document.getElementById('status') ? document.getElementById('status').textContent : '')",
			value -> StringTools.startsWith(value, "\"2|"));
		finish(webView, StringTools.startsWith(pages, "\"2|") ? 0 : 1, "bundled: " + pages);
	}

	/** Runs `script` every quarter second until `done` accepts its value or time runs out, and answers the last value. **/
	static function poll(webView:WebView, script:String, done:String->Bool):String
	{
		var last = "";
		var asked = false;
		var next = 0.0;
		pump(() ->
		{
			if (!asked && Timer.stamp() >= next)
			{
				asked = true;
				webView.evaluateJavaScript(script, (ok, value) ->
				{
					asked = false;
					next = Timer.stamp() + 0.25;
					last = ok ? value : "error " + value;
				});
			}
			return done(last);
		});
		return last;
	}

	static function pump(done:Void->Bool):Bool
	{
		final deadline = Timer.stamp() + TIMEOUT_SECONDS;
		while (!done())
		{
			if (Timer.stamp() > deadline)
			{
				return false;
			}
			WebView.processEvents();
			Sys.sleep(0.005);
		}
		return true;
	}

	static function finish(webView:WebView, code:Int, message:String)
	{
		Sys.println((code == 0 ? "OK: " : "FAILED: ") + message);
		PdfView.release(webView);
		webView.close();
		Sys.exit(code);
	}
}
