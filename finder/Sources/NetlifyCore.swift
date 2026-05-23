import Foundation
import Darwin
import Security
import CommonCrypto
import CryptoKit

let kService   = "com.pbonger.netlify-share"
let kAccount   = "access_token"
let kOAuthPort: Int32 = 34000

// MARK: - Keychain

func tokenGet() -> String? {
    let q: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: kService,
        kSecAttrAccount: kAccount,
        kSecReturnData: true,
        kSecMatchLimit: kSecMatchLimitOne
    ]
    var out: AnyObject?
    guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
          let data = out as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}

func tokenSet(_ value: String) {
    let data = Data(value.utf8)
    let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                               kSecAttrService: kService,
                               kSecAttrAccount: kAccount]
    if SecItemCopyMatching(q as CFDictionary, nil) == errSecItemNotFound {
        var add = q; add[kSecValueData] = data
        SecItemAdd(add as CFDictionary, nil)
    } else {
        SecItemUpdate(q as CFDictionary, [kSecValueData: data] as CFDictionary)
    }
}

// MARK: - OAuth

func oauthCallback() throws -> String {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { throw Fail("socket() failed") }
    defer { Darwin.close(fd) }

    var yes: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, 4)

    var sa = sockaddr_in()
    sa.sin_family = sa_family_t(AF_INET)
    sa.sin_port = UInt16(kOAuthPort).bigEndian
    sa.sin_len  = UInt8(MemoryLayout<sockaddr_in>.size)
    withUnsafePointer(to: &sa) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    listen(fd, 1)

    let client = accept(fd, nil, nil)
    guard client >= 0 else { throw Fail("accept() failed") }
    defer { Darwin.close(client) }

    var buf = [CChar](repeating: 0, count: 8192)
    read(client, &buf, buf.count - 1)
    let req  = String(cString: buf)
    let line = req.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""

    var code: String?
    if let r = line.range(of: "code=") {
        let s = String(line[r.upperBound...].prefix(while: { $0 != "&" && $0 != " " && $0 != "\r" }))
        if !s.isEmpty { code = s }
    }

    let msg  = code != nil ? "Authenticated — you can close this tab." : "Authentication failed."
    let resp = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n<h2>\(msg)</h2>"
    resp.withCString { write(client, $0, Int(strlen($0))) }

    guard let c = code else { throw Fail("No code in OAuth callback") }
    return c
}

func exchangeCode(_ code: String, redirectUri: String) throws -> String {
    var req = URLRequest(url: URL(string: "https://api.netlify.com/oauth/token")!)
    req.httpMethod = "POST"
    req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    req.httpBody = Data(("grant_type=authorization_code"
        + "&code=\(code.pct)"
        + "&client_id=\(NETLIFY_CLIENT_ID.pct)"
        + "&client_secret=\(NETLIFY_CLIENT_SECRET.pct)"
        + "&redirect_uri=\(redirectUri.pct)").utf8)
    let (data, resp) = try syncRequest(req)
    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
    guard (200...299).contains(status) else {
        throw Fail("Token exchange \(status): \(String(data: data, encoding: .utf8) ?? "")")
    }
    guard let token = jsonValue(String(data: data, encoding: .utf8) ?? "", key: "access_token") else {
        throw Fail("No access_token in response")
    }
    return token
}

func login() throws -> String {
    let redirectUri = "http://localhost:\(kOAuthPort)"
    let authUrl = "https://app.netlify.com/authorize"
        + "?client_id=\(NETLIFY_CLIENT_ID.pct)"
        + "&redirect_uri=\(redirectUri.pct)"
        + "&response_type=code"

    var code: String?; var serverErr: Error?
    let sem = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        do   { code = try oauthCallback() }
        catch { serverErr = error }
        sem.signal()
    }

    run("/usr/bin/open", args: [authUrl])
    guard sem.wait(timeout: .now() + 300) == .success else { throw Fail("OAuth timed out") }
    if let e = serverErr { throw e }
    guard let c = code else { throw Fail("Login cancelled") }

    let token = try exchangeCode(c, redirectUri: redirectUri)
    tokenSet(token)
    return token
}

// MARK: - HTML / Zip / Upload

func wrapHtml(_ html: String) -> String {
    let b64 = Data(html.utf8).base64EncodedString()
    return """
    <!DOCTYPE html>
    <html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body><script>
    (function(){var b=atob('\(b64)');var a=new Uint8Array(b.length);for(var i=0;i<b.length;i++)a[i]=b.charCodeAt(i);var h=new TextDecoder().decode(a);document.open();document.write(h);document.close();})();
    </script></body></html>
    """
}

func encryptHtml(_ html: String, password: String) throws -> String {
    var saltBytes = [UInt8](repeating: 0, count: 16)
    guard SecRandomCopyBytes(kSecRandomDefault, 16, &saltBytes) == errSecSuccess else {
        throw Fail("Failed to generate random bytes")
    }
    var keyBytes = [UInt8](repeating: 0, count: 32)
    password.withCString { pwPtr in
        saltBytes.withUnsafeBufferPointer { saltPtr in
            _ = CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                pwPtr, strlen(pwPtr),
                saltPtr.baseAddress, saltBytes.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                100_000,
                &keyBytes, 32
            )
        }
    }
    let key   = SymmetricKey(data: Data(keyBytes))
    let nonce = AES.GCM.Nonce()
    let box   = try AES.GCM.seal(Data(html.utf8), using: key, nonce: nonce)
    let ivB64 = nonce.withUnsafeBytes { Data($0) }.base64EncodedString()
    let ctB64 = (box.ciphertext + box.tag).base64EncodedString()
    return wrapperHtml(salt: Data(saltBytes).base64EncodedString(), iv: ivB64, ct: ctB64)
}

func wrapperHtml(salt: String, iv: String, ct: String) -> String {
"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Protected Page</title>
<style>
  body{font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#f5f5f5}
  .box{background:#fff;padding:2rem;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,.12);width:320px}
  h2{margin:0 0 1rem;font-size:1.1rem}
  input{width:100%;padding:.5rem;border:1px solid #ddd;border-radius:4px;font-size:1rem;box-sizing:border-box}
  button{margin-top:.75rem;width:100%;padding:.5rem;background:#00ad9f;color:#fff;border:none;border-radius:4px;font-size:1rem;cursor:pointer}
  button:hover{background:#009688}
  .err{color:#c0392b;font-size:.85rem;margin-top:.5rem;display:none}
</style>
</head>
<body>
<div class="box">
  <h2>🔒 Password protected</h2>
  <input type="password" id="p" placeholder="Enter password" autofocus>
  <button onclick="go()">Unlock</button>
  <div class="err" id="e">Wrong password — try again.</div>
</div>
<script>
const S='\(salt)',I='\(iv)',C='\(ct)';
const b=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
async function go(){
  try{
    const km=await crypto.subtle.importKey('raw',new TextEncoder().encode(document.getElementById('p').value),'PBKDF2',false,['deriveKey']);
    const k=await crypto.subtle.deriveKey({name:'PBKDF2',salt:b(S),iterations:100000,hash:'SHA-256'},km,{name:'AES-GCM',length:256},false,['decrypt']);
    const plain=await crypto.subtle.decrypt({name:'AES-GCM',iv:b(I)},k,b(C));
    document.open();document.write(new TextDecoder().decode(plain));document.close();
  }catch{document.getElementById('e').style.display='block';}
}
document.getElementById('p').addEventListener('keydown',e=>{if(e.key==='Enter')go();});
</script>
</body>
</html>
"""
}

func makeZip(_ content: String) throws -> URL {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    try Data(content.utf8).write(to: tmp.appendingPathComponent("index.html"))
    try Data("/*\n  Content-Type: text/html; charset=utf-8\n".utf8)
        .write(to: tmp.appendingPathComponent("_headers"))
    let zip = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
    try runChecked("/usr/bin/zip", args: [
        "-j", zip.path,
        tmp.appendingPathComponent("index.html").path,
        tmp.appendingPathComponent("_headers").path
    ])
    try FileManager.default.removeItem(at: tmp)
    return zip
}

func netlifyUpload(zipURL: URL, token: String) throws -> String {
    let zipData = try Data(contentsOf: zipURL)
    try FileManager.default.removeItem(at: zipURL)

    var req = URLRequest(url: URL(string: "https://api.netlify.com/api/v1/sites")!)
    req.httpMethod = "POST"
    req.setValue("application/zip", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.httpBody = zipData

    let (data, resp) = try syncRequest(req)
    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
    guard (200...299).contains(status) else {
        throw Fail("Netlify API \(status): \(String(data: data, encoding: .utf8) ?? "")")
    }

    let body = String(data: data, encoding: .utf8) ?? ""
    guard let rawUrl = jsonValue(body, key: "ssl_url") ?? jsonValue(body, key: "url") else {
        throw Fail("No URL in Netlify response")
    }

    let deployId: String? = {
        guard let proto = rawUrl.range(of: "://"),
              let dash  = rawUrl[proto.upperBound...].range(of: "--") else { return nil }
        let id = String(rawUrl[proto.upperBound..<dash.lowerBound])
        return id.allSatisfy(\.isHexDigit) && !id.isEmpty ? id : nil
    }()
    let siteUrl = deployId.map { rawUrl.replacingOccurrences(of: "\($0)--", with: "") } ?? rawUrl

    if let did = deployId {
        for _ in 1...30 {
            Thread.sleep(forTimeInterval: 2)
            var poll = URLRequest(url: URL(string: "https://api.netlify.com/api/v1/deploys/\(did)")!)
            poll.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (pd, _) = try? syncRequest(poll),
               (String(data: pd, encoding: .utf8) ?? "").contains("\"ready\"") { break }
        }
    }
    return siteUrl
}

// MARK: - Clipboard

func copyToClipboard(_ text: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
    let pipe = Pipe()
    p.standardInput = pipe
    try? p.run()
    pipe.fileHandleForWriting.write(Data(text.utf8))
    pipe.fileHandleForWriting.closeFile()
    p.waitUntilExit()
}

// MARK: - Helpers

struct Fail: Error, LocalizedError {
    let errorDescription: String?
    init(_ msg: String) { errorDescription = msg }
}

func syncRequest(_ req: URLRequest) throws -> (Data, URLResponse) {
    var result: (Data, URLResponse)?; var err: Error?
    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { d, r, e in
        if let d, let r { result = (d, r) } else { err = e }
        sem.signal()
    }.resume()
    sem.wait()
    if let e = err { throw e }
    return result!
}

func jsonValue(_ s: String, key: String) -> String? {
    guard let kr = s.range(of: "\"\(key)\""),
          let cr = s[kr.upperBound...].range(of: ":"),
          let qs = s[cr.upperBound...].range(of: "\"") else { return nil }
    let val = String(s[qs.upperBound...].prefix(while: { $0 != "\"" }))
    return val.isEmpty ? nil : val
}

@discardableResult
func run(_ exe: String, args: [String]) -> Int32 {
    let p = Process(); p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
    try? p.run(); p.waitUntilExit(); return p.terminationStatus
}

func runChecked(_ exe: String, args: [String]) throws {
    guard run(exe, args: args) == 0 else { throw Fail("\(exe) failed") }
}

extension String {
    var pct: String { addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self }
    var esc: String { replacingOccurrences(of: "\"", with: "\\\"") }
}
