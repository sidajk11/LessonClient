//
//  WKWebViewContainer.swift
//  LessonClient
//
//  Created by ym on 2/13/26.
//

import SwiftUI
import WebKit

struct CambridgeExtract: Codable, Sendable {
    let eppXref: [String]
    let dxref: [String]
    let cefr: [String]
    let senseDxrefs: [[String]]
    let senseTranslations: [[String]]
}


struct WKWebViewContainer: NSViewRepresentable {
    let url: URL
    var onExtract: (CambridgeExtract) -> Void = { _ in }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        context.coordinator.onExtract = { extract in
            print("📘 Cambridge Extract")
            print("eppXref:", extract.eppXref)
            print("dxref:", extract.dxref)
            print("cefr:", extract.cefr)
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    
    final class Coordinator: NSObject, WKNavigationDelegate {
        var onExtract: (CambridgeExtract) -> Void = { _ in }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
            (function() {
              function textArray(nodeList) {
                return Array.from(nodeList)
                  .map(el => (el.textContent || '').trim())
                  .filter(Boolean);
              }
              function getTextsByClass(cls) {
                return textArray(document.getElementsByClassName(cls));
              }
              function getCEFRLevels() {
                const cefrSelectors = ['.cefr', '.epp-xref', '.dxref'];
                const all = new Set();
                for (const sel of cefrSelectors) {
                  document.querySelectorAll(sel).forEach(el => {
                    const t = (el.textContent || '').trim();
                    if (t) all.add(t);
                  });
                }
                return Array.from(all).filter(t => /^(A1|A2|B1|B2|C1|C2)$/.test(t));
              }

              // Per-sense extraction within '.sense-body.dsense_b'
              const senseBodies = document.getElementsByClassName('sense-body dsense_b');
              const senseDxrefs = [];
              const senseTranslations = [];
              Array.from(senseBodies).forEach(sb => {
                const dx = textArray(sb.getElementsByClassName('dxref'));
                const trans = [
                  ...textArray(sb.getElementsByClassName('trans')),
                  ...textArray(sb.getElementsByClassName('dtrans')),
                  ...textArray(sb.getElementsByClassName('dtrans-se'))
                ];
                senseDxrefs.push(dx);
                senseTranslations.push(trans);
              });

              const result = {
                eppXref: getTextsByClass('epp-xref'),
                dxref: getTextsByClass('dxref'), // global dxref fallback
                cefr: getCEFRLevels(),
                senseDxrefs: senseDxrefs,
                senseTranslations: senseTranslations
              };
              return JSON.stringify(result);
            })();
            """
            webView.evaluateJavaScript(js) { [weak self] value, error in
                if let error { print("[WKWebView JS Error]", error.localizedDescription) }
                print("[WKWebView JS Raw]", String(describing: value))
                guard error == nil else { return }
                guard let json = value as? String, let data = json.data(using: .utf8) else { return }
                if let decoded = try? JSONDecoder().decode(CambridgeExtract.self, from: data) {
                    print("[WKWebView JS Decoded]", decoded)
                    self?.onExtract(decoded)
                } else {
                    print("[WKWebView JS Decode Failed]")
                }
            }
        }
    }
}

