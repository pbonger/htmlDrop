import Foundation
import Darwin
import Security
import CommonCrypto
import CryptoKit

// MARK: - Upload

func htmlDropUpload(_ html: String) throws -> String {
    let json = "{\"html\":\(jsonEscape(html)),\"ttl\":\"3d\"}"
    var req = URLRequest(url: URL(string: "https://pagedrop.io/api/upload")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = Data(json.utf8)
    let (data, resp) = try syncRequest(req)
    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
    guard (200...299).contains(status) else {
        throw Fail("HTML Drop API \(status): \(String(data: data, encoding: .utf8) ?? "")")
    }
    let body = String(data: data, encoding: .utf8) ?? ""
    guard let url = jsonValue(body, key: "url")
               ?? jsonValue(body, key: "link")
               ?? jsonValue(body, key: "page_url") else {
        throw Fail("No URL in HTML Drop response: \(body)")
    }
    return url
}

func jsonEscape(_ s: String) -> String {
    var out = "\""
    for c in s.unicodeScalars {
        switch c.value {
        case 0x22: out += "\\\""
        case 0x5C: out += "\\\\"
        case 0x0A: out += "\\n"
        case 0x0D: out += "\\r"
        case 0x09: out += "\\t"
        default:
            if c.value < 0x20 { out += String(format: "\\u%04x", c.value) }
            else { out.unicodeScalars.append(c) }
        }
    }
    out += "\""
    return out
}

// MARK: - Encryption

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
