#if macro
import haxe.macro.Context;
#end

/**
	A program that shows a PDF and names no webview compiles in none. Run as
	`haxe build/no-webview.hxml`, which compiles `ShowOnly` (test/src/ShowOnly.hx) and fails when any
	module of StageWebView or OpenFL was typed. pdfview 0.1.0 named StageWebView's
	`WebView` in `PdfTarget`, which built its native backend, and on Linux linked
	WebKitGTK, into a program that shows its pages through Lime's.
**/
class CompilesInNoWebView
{
	#if macro
	public static function check():Void
	{
		Context.onAfterTyping(function(types)
		{
			var hits = [];
			for (t in types)
			{
				var module = switch t
				{
					case TClassDecl(c): c.get().module;
					case TAbstract(a): a.get().module;
					case TEnumDecl(e): e.get().module;
					case TTypeDecl(d): d.get().module;
				}
				if (StringTools.startsWith(module, "webview.") || StringTools.startsWith(module, "openfl.") || module == "webview")
				{
					if (hits.indexOf(module) < 0) hits.push(module);
				}
			}
			if (hits.length > 0)
			{
				Context.fatalError("showing a PDF compiled in " + hits.join(", "), Context.currentPos());
			}
			Sys.println("showing a PDF compiled in no webview");
		});
	}
	#end
}
