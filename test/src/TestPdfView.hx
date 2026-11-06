import haxe.io.Bytes;
import pdfview.PdfTarget;
import pdfview.PdfView;
import utest.Assert;

/** What `show()` asks of its target, and the page it builds, without a webview. **/
class TestPdfView extends utest.Test
{
	var loaded:Array<String>;
	var shown:Array<String>;
	var target:PdfTarget;
	var file:String;

	function setup()
	{
		loaded = [];
		shown = [];
		target = {load: url -> loaded.push(url), loadHTML: html -> shown.push(html)};
		file = haxe.io.Path.join([Sys.getCwd(), "bin", "two pages & more.pdf"]);
		if (!sys.FileSystem.exists(haxe.io.Path.directory(file)))
		{
			sys.FileSystem.createDirectory(haxe.io.Path.directory(file));
		}
		sys.io.File.saveBytes(file, Bytes.ofString("%PDF-1.4 not really"));
	}

	function teardown()
	{
		PdfView.release(target);
		sys.FileSystem.deleteFile(file);
	}

	function testAnyObjectWithTheTwoCallsIsATarget()
	{
		// A class instance, as StageWebView's and Lime's WebView are: matched by its two calls.
		final view = new FakeView();
		PdfView.show(view, file, NATIVE);
		Assert.same([PdfView.fileUrl(sys.FileSystem.absolutePath(file))], view.loaded);
	}

	function testAFileUrlEncodesEachSegmentAndKeepsTheDrive()
	{
		Assert.equals("file:///C:/Users/a%20b/r%26d.pdf", PdfView.fileUrl("C:\\Users\\a b\\r&d.pdf"));
		Assert.equals("file:///home/rater/report%20%231.pdf", PdfView.fileUrl("/home/rater/report #1.pdf"));
	}

	function testNativeNavigatesToTheFile()
	{
		PdfView.show(target, file, NATIVE);
		Assert.same([PdfView.fileUrl(sys.FileSystem.absolutePath(file))], loaded);
		Assert.equals(0, shown.length);
	}

	function testTheBundledPageCarriesTheDocumentAndAnEscapedTitle()
	{
		final html = PdfView.page(Bytes.ofString("%PDF-1.4"), "a <b> & c.pdf");
		Assert.isTrue(html.indexOf("<title>a &lt;b&gt; &amp; c.pdf</title>") >= 0);
		Assert.isTrue(html.indexOf("atob('" + haxe.crypto.Base64.encode(Bytes.ofString("%PDF-1.4")) + "')") >= 0);
		Assert.isTrue(html.indexOf("globalThis.pdfjsLib=") >= 0);
		Assert.isTrue(html.indexOf("globalThis.pdfjsWorker=") >= 0);
	}

	function testBundledWritesAPageOnWindowsAndReleaseRemovesIt()
	{
		PdfView.show(target, file, BUNDLED);
		if (Sys.systemName() == "Windows")
		{
			// WebView2 takes at most 2 MB through NavigateToString, so the page goes through a file.
			Assert.equals(1, loaded.length);
			Assert.equals(0, shown.length);
			final page = StringTools.urlDecode(loaded[0].substr("file:///".length));
			Assert.isTrue(sys.FileSystem.exists(page));
			Assert.isTrue(sys.io.File.getContent(page).indexOf("<title>two pages &amp; more.pdf</title>") >= 0);

			// The same webview reuses its page, and release removes it: it holds the document.
			PdfView.show(target, file, BUNDLED);
			Assert.equals(loaded[0], loaded[1]);
			PdfView.release(target);
			Assert.isFalse(sys.FileSystem.exists(page));
		}
		else
		{
			Assert.equals(0, loaded.length);
			Assert.equals(1, shown.length);
		}
	}

	function testGoingNativeRemovesTheBundledPage()
	{
		if (Sys.systemName() != "Windows")
		{
			Assert.pass();
			return;
		}
		PdfView.show(target, file, BUNDLED);
		final page = StringTools.urlDecode(loaded[0].substr("file:///".length));
		PdfView.show(target, file, NATIVE);
		Assert.isFalse(sys.FileSystem.exists(page));
	}

	function testAutoUsesTheTargetsOwnViewerWhereItHasOne()
	{
		PdfView.show(target, file);
		if (PdfView.hasNativeViewer)
		{
			Assert.same([PdfView.fileUrl(sys.FileSystem.absolutePath(file))], loaded);
		}
		else
		{
			Assert.equals(1, loaded.length + shown.length);
			Assert.notEquals(PdfView.fileUrl(sys.FileSystem.absolutePath(file)), loaded[0]);
		}
	}
}

private class FakeView
{
	public var loaded:Array<String> = [];

	public function new() {}

	public function load(url:String):Void
	{
		loaded.push(url);
	}

	public function loadHTML(html:String):Void {}
}
