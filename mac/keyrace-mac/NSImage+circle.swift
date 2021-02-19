// Created by Jessie Frazelle on 2/18/21.

import Foundation
import SwiftUI

extension NSImage {
    // Copies this image to a new one with a circular mask.
    func circle() -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        let frame = NSRect(origin: .zero, size: size)
        NSBezierPath(ovalIn: frame).addClip()
        draw(at: .zero, from: frame, operation: .sourceOver, fraction: 1)

        image.unlockFocus()
        return image
    }
}
