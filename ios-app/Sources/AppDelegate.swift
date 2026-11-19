import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = WebViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

class WebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    private var webView: WKWebView!

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Keyboard: refresh layout on frame changes (the web app listens to visualViewport).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )

        let bundle = Bundle.main
        if let indexURL = bundle.url(forResource: "index", withExtension: "html", subdirectory: "www")
            ?? bundle.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(indexURL, allowingReadAccessTo: bundle.bundleURL)
        } else {
            webView.loadHTMLString(
                "<html><body style='background:#0b140e;color:#fff;font-family:sans-serif;display:grid;place-items:center;height:100%'><p>资源缺失：请重新构建（www 目录未打包）</p></body></html>",
                baseURL: nil
            )
        }
    }

    @objc private func keyboardFrameChanged() {
        webView.evaluateJavaScript(
            "window.dispatchEvent(new Event('resize'));",
            completionHandler: nil
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // The system draws its own home indicator inside the native app.
        webView.evaluateJavaScript(
            "document.documentElement.classList.add('native');",
            completionHandler: nil
        )
    }
}
