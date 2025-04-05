import SwiftUI
import WebKit


struct WebView: UIViewRepresentable {
    let url: URL
    let onSendMessage: (WKWebView) -> Void

    func makeUIView(context: Context) -> WKWebView {
        
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        
        let teleportScript = """
        var TeleportProto = function() {};
        TeleportProto.prototype.postEvent = function(eventName, eventData) {
            window.webkit.messageHandlers.origin.postMessage({
                eventName: eventName,
                eventData: eventData
            });
        };
        TeleportProto.prototype.receiveEvent = function(eventName, eventData) {
            console.log('Received from iOS:', eventName, eventData);
        };
        var Teleport = new TeleportProto();
        """

        let script = WKUserScript(source: teleportScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(script)

        
        contentController.add(context.coordinator, name: "origin")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        
        onSendMessage(uiView)
    }

    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "origin",
               let body = message.body as? [String: Any],
               let eventName = body["eventName"] as? String,
               let eventData = body["eventData"] as? String {
                print("Received from web: \(eventName), \(eventData)")
            }
        }


                func sendEvent(to webView: WKWebView, eventName: String, eventData: String) {
                    let script = "Teleport.receiveEvent('\(eventName)', '\(eventData)');"
                    webView.evaluateJavaScript(script) { result, error in
                        if let error = error {
                            print("Error sending to web: \(error)")
                        } else {
                            print("Sent to web: \(eventName), \(eventData)")
                        }
                    }
                }
    }
}


struct ContentView: View {
    let url = URL(string: "http://192.168.40.184:5500")!
    @State private var sendTrigger = false
    
    var body: some View {
        VStack {
                    WebView(url: url) { webView in
                        
                        if sendTrigger {
                            WebView.Coordinator().sendEvent(to: webView, eventName: "hello_from_ios", eventData: "Hi from Swift!")
                            sendTrigger = false
                        }
                    }
                    .ignoresSafeArea()

                    
                    Button("Send to Web") {
                        sendTrigger = true
                    }
                    .padding()
                }
    }
}

#Preview {
    ContentView()
}


