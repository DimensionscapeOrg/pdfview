#if macro
package pdfview._internal;

import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.io.File;

/**
	Run from extraParams.hxml. Decides whether this target has a PDF viewer of
	its own and embeds the bundled PDF.js where it does not.
**/
class Embed
{
	static var __included:Bool = false;

	public static function include():Void
	{
		if (__included || Context.defined("display"))
		{
			return;
		}

		__included = true;

		// A plain hxcpp build on Windows does not define `windows`, so the host stands in, as StageWebView does.
		if (Sys.systemName() == "Windows")
		{
			Compiler.define("pdfview_windows");
		}

		// Android WebView has no PDF viewer, and WebKitGTK has one only when the distribution built it with
		// its PDF.js viewer, so Linux and Android use the bundled one. Elsewhere the ~1.8 MB of scripts are
		// only embedded on request.
		var noNative = Context.defined("cpp") && (Context.defined("android") || __isLinuxDesktopTarget());
		if (noNative)
		{
			Compiler.define("pdfview_no_native");
		}

		if (noNative || Context.defined("pdfview_pdfjs"))
		{
			var macroPath = Path.normalize(Context.resolvePath("pdfview/_internal/Embed.hx"));
			var libraryRoot = Path.directory(Path.directory(Path.directory(Path.directory(macroPath))));
			var directory = Path.join([libraryRoot, "assets", "pdfjs"]);
			Context.addResource("pdfview-pdfjs-lib", File.getBytes(Path.join([directory, "pdf.lib.js"])));
			Context.addResource("pdfview-pdfjs-worker", File.getBytes(Path.join([directory, "pdf.worker.js"])));
		}
	}

	static function __isLinuxDesktopTarget():Bool
	{
		if (Context.defined("android") || Context.defined("ios") || Context.defined("windows") || Context.defined("mac"))
		{
			return false;
		}

		return Context.defined("linux") || Sys.systemName() == "Linux";
	}
}
#end
