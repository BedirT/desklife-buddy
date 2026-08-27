import AppKit

#if DEBUG
    enum OverlayVerificationCapture {
        static func write(view: NSView?, prefix: String) -> Bool {
            guard let view,
                  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds),
                  let context = NSGraphicsContext(bitmapImageRep: bitmap)
            else {
                return false
            }
            view.layoutSubtreeIfNeeded()
            view.displayIgnoringOpacity(view.bounds, in: context)
            guard let data = bitmap.representation(using: .png, properties: [:]),
                  let caches = FileManager.default.urls(
                      for: .cachesDirectory,
                      in: .userDomainMask,
                  ).first
            else {
                return false
            }
            let filename = "\(prefix)-\(ProcessInfo.processInfo.processIdentifier).png"
            do {
                try data.write(to: caches.appendingPathComponent(filename), options: .atomic)
                return true
            } catch {
                return false
            }
        }
    }
#endif
