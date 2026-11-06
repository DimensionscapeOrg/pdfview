/** Shows a PDF and names no webview. See CompilesInNoWebView. **/
class ShowOnly
{
	static function main()
	{
		pdfview.PdfView.show({load: function(url:String) {}, loadHTML: function(html:String) {}}, "report.pdf");
	}
}
