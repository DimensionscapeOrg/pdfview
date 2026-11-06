package;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
	Regenerates assets/pdfjs from a pdfjs-dist package so the viewer can run
	inline, with no file access and no Web Worker.

	PDF.js ships ES modules that end in one `export{...}` statement. That
	statement is rewritten into a global: `globalThis.pdfjsLib` for the library,
	and `globalThis.pdfjsWorker` for the worker, which PDF.js picks up as its
	main-thread fallback. Everything else is copied byte for byte.

	Usage:

	```
	npm pack pdfjs-dist@4.10.38
	tar -xzf pdfjs-dist-4.10.38.tgz -C <dir>
	haxe -cp build --run PdfJsBundle <dir>/package
	```

	Run it from the library root; the output goes to assets/pdfjs.
**/
class PdfJsBundle
{
	public static function main():Void
	{
		var args = Sys.args();
		if (args.length < 1)
		{
			Sys.println("usage: haxe -cp build --run PdfJsBundle <extracted pdfjs-dist package directory>");
			Sys.exit(1);
		}

		var packageDirectory = args[0];
		var output = args.length > 1 ? args[1] : "assets/pdfjs";
		if (!FileSystem.exists(output))
		{
			FileSystem.createDirectory(output);
		}

		var manifest:Dynamic = haxe.Json.parse(File.getContent(Path.join([packageDirectory, "package.json"])));

		File.saveContent(Path.join([output, "pdf.lib.js"]), __globalize(File.getContent(Path.join([packageDirectory, "legacy", "build", "pdf.min.mjs"])), "pdfjsLib"));
		File.saveContent(Path.join([output, "pdf.worker.js"]),
			__globalize(File.getContent(Path.join([packageDirectory, "legacy", "build", "pdf.worker.min.mjs"])), "pdfjsWorker"));
		File.copy(Path.join([packageDirectory, "LICENSE"]), Path.join([output, "LICENSE"]));
		File.saveContent(Path.join([output, "VERSION"]), manifest.name + "@" + manifest.version + "\n");

		Sys.println("wrote " + output + " from " + manifest.name + "@" + manifest.version);
	}

	private static function __globalize(source:String, global:String):String
	{
		var exportPattern = ~/export\s*\{([^}]*)\}\s*;?\s*$/;
		if (!exportPattern.match(source))
		{
			throw "No trailing export statement found for " + global;
		}

		var fields = [];
		for (binding in exportPattern.matched(1).split(","))
		{
			var parts = StringTools.trim(binding).split(" as ");
			var local = StringTools.trim(parts[0]);
			var exported = parts.length > 1 ? StringTools.trim(parts[1]) : local;
			fields.push(exported + ":" + local);
		}

		var result = exportPattern.matchedLeft() + "globalThis." + global + "={" + fields.join(",") + "};\n";
		if (result.indexOf("</script") >= 0)
		{
			throw global + " contains </script and cannot be inlined";
		}

		return result;
	}
}
