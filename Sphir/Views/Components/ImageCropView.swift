//
//  ImageCropView.swift
//  Sphir
//
//  A dependency-free crop/select-area overlay. Shows an image with a
//  draggable, resizable selection rectangle (four corner handles + a movable
//  interior) and reports the selection in normalized (0...1) image coordinates.
//

import SwiftUI
import UIKit

struct ImageCropView: View {
    let image: UIImage
    /// Selection in normalized image space (0...1), origin top-left.
    @Binding var normalizedRect: CGRect

    private enum Corner: CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }

    @State private var cropRect: CGRect = .zero     // points, in container space
    @State private var moveStart: CGRect?           // baseline for the move gesture
    @State private var didInit = false

    private let handleSize: CGFloat = 28
    private let minSide: CGFloat = 44
    private let space = "cropSpace"

    var body: some View {
        GeometryReader { geo in
            let bounds = Self.fittedRect(imageSize: image.size, in: geo.size)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                dimming(container: geo.size)

                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .allowsHitTesting(false)

                // Movable interior.
                Color.white.opacity(0.001)
                    .frame(width: max(cropRect.width, 1), height: max(cropRect.height, 1))
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .gesture(moveGesture(bounds: bounds))

                ForEach(Array(Corner.allCases.enumerated()), id: \.offset) { _, corner in
                    handleCircle
                        .position(point(of: corner, in: cropRect))
                        .gesture(cornerGesture(corner, bounds: bounds))
                }
            }
            .coordinateSpace(name: space)
            .onAppear {
                guard !didInit else { return }
                didInit = true
                cropRect = bounds.insetBy(dx: bounds.width * 0.12, dy: bounds.height * 0.12)
                publish(bounds: bounds)
            }
        }
    }

    private var handleCircle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(SphirColor.taupe, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 2)
    }

    // MARK: - Dimming (four bands around the crop)

    private func dimming(container: CGSize) -> some View {
        let dim = Color.black.opacity(0.45)
        return ZStack(alignment: .topLeading) {
            // Top
            dim.frame(width: container.width, height: max(cropRect.minY, 0))
                .position(x: container.width / 2, y: max(cropRect.minY, 0) / 2)
            // Bottom
            dim.frame(width: container.width, height: max(container.height - cropRect.maxY, 0))
                .position(x: container.width / 2, y: cropRect.maxY + max(container.height - cropRect.maxY, 0) / 2)
            // Left
            dim.frame(width: max(cropRect.minX, 0), height: cropRect.height)
                .position(x: max(cropRect.minX, 0) / 2, y: cropRect.midY)
            // Right
            dim.frame(width: max(container.width - cropRect.maxX, 0), height: cropRect.height)
                .position(x: cropRect.maxX + max(container.width - cropRect.maxX, 0) / 2, y: cropRect.midY)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Gestures

    private func moveGesture(bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { value in
                let base = moveStart ?? cropRect
                if moveStart == nil { moveStart = cropRect }
                var origin = CGPoint(x: base.minX + value.translation.width,
                                     y: base.minY + value.translation.height)
                origin.x = min(max(origin.x, bounds.minX), bounds.maxX - base.width)
                origin.y = min(max(origin.y, bounds.minY), bounds.maxY - base.height)
                cropRect = CGRect(origin: origin, size: base.size)
                publish(bounds: bounds)
            }
            .onEnded { _ in moveStart = nil }
    }

    private func cornerGesture(_ corner: Corner, bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { value in
                let fixed = point(of: opposite(of: corner), in: cropRect)
                var p = value.location
                p.x = min(max(p.x, bounds.minX), bounds.maxX)
                p.y = min(max(p.y, bounds.minY), bounds.maxY)

                var minX = min(p.x, fixed.x)
                var maxX = max(p.x, fixed.x)
                var minY = min(p.y, fixed.y)
                var maxY = max(p.y, fixed.y)

                // Enforce a minimum size while staying in bounds.
                if maxX - minX < minSide {
                    if p.x <= fixed.x { minX = max(bounds.minX, fixed.x - minSide) }
                    else { maxX = min(bounds.maxX, fixed.x + minSide) }
                }
                if maxY - minY < minSide {
                    if p.y <= fixed.y { minY = max(bounds.minY, fixed.y - minSide) }
                    else { maxY = min(bounds.maxY, fixed.y + minSide) }
                }
                cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                publish(bounds: bounds)
            }
    }

    // MARK: - Geometry helpers

    private func point(of corner: Corner, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft:     return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:    return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:  return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private func opposite(of corner: Corner) -> Corner {
        switch corner {
        case .topLeft:     return .bottomRight
        case .topRight:    return .bottomLeft
        case .bottomLeft:  return .topRight
        case .bottomRight: return .topLeft
        }
    }

    private func publish(bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let x = (cropRect.minX - bounds.minX) / bounds.width
        let y = (cropRect.minY - bounds.minY) / bounds.height
        let w = cropRect.width / bounds.width
        let h = cropRect.height / bounds.height
        normalizedRect = CGRect(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1),
            width: min(max(w, 0), 1),
            height: min(max(h, 0), 1)
        )
    }

    /// Aspect-fit rect of `imageSize` centered in `container`.
    static func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (container.width - size.width) / 2,
                             y: (container.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }
}

#Preview {
    let sample = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 420)).image { ctx in
        UIColor(red: 0.55, green: 0.48, blue: 0.41, alpha: 1).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 420))
        ("Sphir" as NSString).draw(at: CGPoint(x: 60, y: 170), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 48),
            .foregroundColor: UIColor.white
        ])
    }
    return ImageCropView(image: sample, normalizedRect: .constant(CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)))
        .frame(height: 520)
        .padding()
        .background(SphirColor.background)
}

extension UIImage {
    /// Redraw the image in `.up` orientation so pixel coordinates match the
    /// displayed layout (crop math becomes orientation-independent).
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// Crop to a normalized (0...1) rect in the image's own (top-left) space.
    func cropped(toNormalized rect: CGRect) -> UIImage {
        let source = normalizedUp()
        guard let cg = source.cgImage else { return self }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let pixelRect = CGRect(
            x: rect.minX * w,
            y: rect.minY * h,
            width: rect.width * w,
            height: rect.height * h
        ).integral
        guard pixelRect.width >= 1, pixelRect.height >= 1,
              let cropped = cg.cropping(to: pixelRect) else { return source }
        return UIImage(cgImage: cropped, scale: source.scale, orientation: .up)
    }
}
