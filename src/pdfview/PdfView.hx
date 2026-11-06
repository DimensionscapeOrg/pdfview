package pdfview;

import haxe.crypto.Base64;
import haxe.ds.ObjectMap;
import haxe.io.Bytes;
import haxe.io.Path;

/**
	Shows a PDF in a webview: StageWebView's, Lime's, or anything with the two
	calls `PdfTarget` names.

	WebView2 and WKWebView display a PDF themselves, so on Windows, macOS and iOS
	`show()` navigates to the file. Android WebView has no viewer, and WebKitGTK
	has one only when the distribution built it in, so on Linux and Android
	`show()` renders the file with a bundled PDF.js (assets/pdfjs, built by
	build/PdfJsBundle.hx) instead.

	The bundled page carries the library, its worker and the document bytes
	inline, so it needs no file access and no Web Worker: PDF.js finds
	`globalThis.pdfjsWorker` and runs its worker code on the main thread. The
	`pdfview._internal.Embed` macro embeds the two scripts as resources on Linux
	and Android, or anywhere with `-D pdfview_pdfjs`.
**/
class PdfView
{
	public static inline final LIBRARY_RESOURCE:String = "pdfview-pdfjs-lib";
	public static inline final WORKER_RESOURCE:String = "pdfview-pdfjs-worker";

	/** Whether `AUTO` uses the webview's own viewer on this target. **/
	public static var hasNativeViewer(get, never):Bool;

	/** Whether the bundled PDF.js viewer is compiled in. **/
	public static var isBundled(get, never):Bool;

	// The viewer pages written for WebView2, by the webview they were shown in. See `show()`.
	static var __pages:ObjectMap<{}, String> = new ObjectMap();

	/**
		Shows the PDF at `path` in `target`.

		Where the bundled viewer is used on Windows, the page is written to a file in
		TEMP first, because WebView2's NavigateToString takes at most 2 MB and the
		page is larger. That file holds the document, so call `release()` when the
		webview is done with it.

		@throws Dynamic Thrown when `BUNDLED` is requested but the viewer was not
			compiled in (define `pdfview_pdfjs`).
	**/
	public static function show(target:PdfTarget, path:String, viewer:PdfViewer = AUTO):Void
	{
		#if sys
		path = sys.FileSystem.absolutePath(path);
		#end

		if (viewer == BUNDLED || (viewer == AUTO && !hasNativeViewer))
		{
			#if sys
			var html = page(sys.io.File.getBytes(path), Path.withoutDirectory(path));
			#if (!android && !ios && (windows || pdfview_windows))
			var file = __pages.get(target);
			if (file == null)
			{
				var temp = Sys.getEnv("TEMP");
				file = Path.join([temp != null ? temp : ".", "pdfview-" + Std.string(Date.now().getTime()) + "-" + Std.random(1000000) + ".html"]);
				__pages.set(target, file);
			}

			sys.io.File.saveContent(file, html);
			target.load(fileUrl(file));
			#else
			target.loadHTML(html);
			#end
			#else
			throw "PdfView.show needs file access";
			#end
			return;
		}

		release(target);
		target.load(fileUrl(path));
	}

	/**
		Removes the viewer page `show()` wrote for `target`, if it wrote one. Safe to
		call when it did not.
	**/
	public static function release(target:PdfTarget):Void
	{
		var file = __pages.get(target);
		if (file == null)
		{
			return;
		}

		__pages.remove(target);
		#if sys
		try
		{
			if (sys.FileSystem.exists(file))
			{
				sys.FileSystem.deleteFile(file);
			}
		}
		catch (_:Dynamic) {}
		#end
	}

	/**
		A self-contained page that renders `pdf` with the bundled PDF.js. When every
		page is drawn the root element's `data-pages` attribute holds the page count.

		@throws Dynamic Thrown when the viewer was not compiled in.
	**/
	public static function page(pdf:Bytes, title:String):String
	{
		var library = haxe.Resource.getString(LIBRARY_RESOURCE);
		var worker = haxe.Resource.getString(WORKER_RESOURCE);
		if (library == null || worker == null)
		{
			throw "The bundled PDF.js viewer is not compiled in. Define pdfview_pdfjs to include it.";
		}

		var buffer = new StringBuf();
		buffer.add('<!doctype html>\n<html>\n<head>\n<meta charset="utf-8">\n');
		buffer.add('<meta name="viewport" content="width=device-width, initial-scale=1">\n');
		buffer.add("<title>" + StringTools.htmlEscape(title) + "</title>\n");
		buffer.add("<style>
	html, body { margin: 0; background: #525659; }
	#status { color: #ffffff; font: 14px sans-serif; text-align: center; padding: 24px; }
	#pages { display: flex; flex-direction: column; align-items: center; gap: 12px; padding: 12px 0; }
	#pages canvas { background: #ffffff; box-shadow: 0 1px 4px rgba(0, 0, 0, 0.4); max-width: calc(100% - 24px); height: auto; }
</style>
</head>
<body>
<div id=\"status\">Loading PDF…</div>
<div id=\"pages\"></div>
");
		// Separate module scripts keep the two minified bundles' top-level names apart.
		buffer.add('<script type="module">\n');
		buffer.add(worker);
		buffer.add('</script>\n<script type="module">\n');
		buffer.add(library);
		buffer.add('</script>\n<script type="module">\n');
		// PDF.js paces display rendering with requestAnimationFrame, which WebKit pauses for a window that is
		// off screen (a hidden webview on macOS), so a timer stands in when no frame arrives.
		buffer.add("(function () {
	var frame = window.requestAnimationFrame.bind(window);
	window.requestAnimationFrame = function (callback) {
		var called = false;
		var run = function (time) { if (!called) { called = true; callback(time); } };
		setTimeout(function () { run(performance.now()); }, 50);
		return frame(run);
	};
})();
(async function () {
	var status = document.getElementById('status');
	try {
		var binary = atob('" + Base64.encode(pdf) + "');
		var data = new Uint8Array(binary.length);
		for (var i = 0; i < binary.length; i++) { data[i] = binary.charCodeAt(i); }
		var pdf = await globalThis.pdfjsLib.getDocument({ data: data, isEvalSupported: false }).promise;
		var ratio = window.devicePixelRatio || 1;
		var container = document.getElementById('pages');
		for (var number = 1; number <= pdf.numPages; number++) {
			var page = await pdf.getPage(number);
			var base = page.getViewport({ scale: 1 });
			var cssScale = Math.min(2, Math.max(0.25, (document.documentElement.clientWidth - 24) / base.width));
			var viewport = page.getViewport({ scale: cssScale * ratio });
			var canvas = document.createElement('canvas');
			canvas.width = Math.floor(viewport.width);
			canvas.height = Math.floor(viewport.height);
			canvas.style.width = Math.floor(viewport.width / ratio) + 'px';
			container.appendChild(canvas);
			await page.render({ canvasContext: canvas.getContext('2d'), viewport: viewport }).promise;
		}
		status.remove();
		document.documentElement.setAttribute('data-pages', String(pdf.numPages));
	} catch (error) {
		status.textContent = 'Could not show the PDF: ' + (error && error.message ? error.message : error);
	}
})();
</script>
</body>
</html>
");
		return buffer.toString();
	}

	/** A `file://` URL for an absolute path, each segment encoded and a drive letter kept readable. **/
	public static function fileUrl(path:String):String
	{
		var normalized = StringTools.replace(path, "\\", "/");
		var segments = [for (segment in normalized.split("/")) StringTools.urlEncode(segment)];

		// Keep a Windows drive letter readable: file:///C:/...
		if (segments.length > 0 && ~/^[A-Za-z]%3A$/.match(segments[0]))
		{
			segments[0] = segments[0].charAt(0) + ":";
		}

		var joined = segments.join("/");
		return StringTools.startsWith(joined, "/") ? "file://" + joined : "file:///" + joined;
	}

	static inline function get_hasNativeViewer():Bool
	{
		#if pdfview_no_native
		return false;
		#else
		return true;
		#end
	}

	static function get_isBundled():Bool
	{
		return haxe.Resource.listNames().indexOf(LIBRARY_RESOURCE) >= 0;
	}
}
