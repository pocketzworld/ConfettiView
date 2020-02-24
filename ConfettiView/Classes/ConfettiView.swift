import UIKit

private let kAnimationLayerKey = "com.nshipster.animationLayer"

/// A view that emits confetti.
public final class ConfettiView: UIView {
    public init() {
        super.init(frame: .zero)
        commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        isUserInteractionEnabled = false
    }

    // MARK: -
    public func emitConfetti() {
        emit(with: [
          .text("🎉"),
          .text("🙌"),
          .text("🥳"),
          .text("🎊"),
          .shape(.triangle, UIColor(red: 158/255.0, green: 89/255.0, blue: 253/255.0, alpha: 1.0)),
          .shape(.circle, UIColor(red: 37/255.0, green: 198/255.0, blue: 255/255.0, alpha: 1.0)),
          .shape(.triangle, UIColor(red: 109/255.0, green: 255/255.0, blue: 60/255.0, alpha: 1.0)),
          .shape(.square, UIColor(red: 255/255.0, green: 102/255.0, blue: 130/255.0, alpha: 1.0)),
          .shape(.triangle, UIColor(red: 253/255.0, green: 255/255.0, blue: 95/255.0, alpha: 1.0)),
        ])
    }
    /**
     Emits the provided confetti content for a specified duration.

     - Parameters:
        - contents: The contents to be emitted as confetti.
        - duration: The amount of time in seconds to emit confetti before fading out;
                    3.0 seconds by default.
    */
    public func emit(with contents: [Content],
                     for duration: TimeInterval = 3.0)
    {
        let layer = Layer()
        layer.configure(with: contents)
        layer.frame = self.bounds
        layer.needsDisplayOnBoundsChange = true
        self.layer.addSublayer(layer)

        guard duration.isFinite else { return }

        let animation = CAKeyframeAnimation(keyPath: #keyPath(CAEmitterLayer.birthRate))
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        animation.fillMode = .forwards
        animation.values = [1, 0, 0]
        animation.keyTimes = [0, 0.5, 1]
        animation.isRemovedOnCompletion = false

        layer.beginTime = CACurrentMediaTime()
        layer.birthRate = 1.0

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            let transition = CATransition()
            transition.delegate = self
            transition.type = .fade
            transition.duration = 1
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            transition.setValue(layer, forKey: kAnimationLayerKey)
            transition.isRemovedOnCompletion = false

            layer.add(transition, forKey: nil)

            layer.opacity = 0
        }
        layer.add(animation, forKey: nil)
        CATransaction.commit()
    }

    // MARK: UIView

    override public func willMove(toSuperview newSuperview: UIView?) {
        guard let superview = newSuperview else { return }
        frame = superview.bounds
        isUserInteractionEnabled = false
    }

    // MARK: -

    /// Content to be emitted as confetti
    public enum Content {
        /// Confetti shapes
        public enum Shape {
            /// A circle.
            case circle

            /// A triangle.
            case triangle

            /// A square.
            case square

            // A custom shape.
            case custom(CGPath)
        }

        /// A shape with a particular color.
        case shape(Shape, UIColor)

        /// An image with an optional tint color.
        case image(UIImage, UIColor?)

        /// A string of characters.
        case text(String)
    }

    // MARK: -

    private final class Layer: CAEmitterLayer {
        func configure(with contents: [Content]) {
            emitterCells = contents.map { content in
                let cell = CAEmitterCell()

                cell.birthRate = 15.0
                cell.lifetime = 10.0
                cell.velocity = CGFloat(50 * cell.lifetime)
                cell.velocityRange = cell.velocity / 2
                cell.emissionLongitude = .pi
                cell.emissionRange = .pi / 4
                cell.spinRange = .pi * 8
                cell.scaleRange = 0.25
                cell.scale = 1.0 - cell.scaleRange
                cell.contents = content.image.cgImage

                if let color = content.color {
                    cell.color = color.cgColor
                }

                return cell
            }
        }

        // MARK: CALayer

        override func layoutSublayers() {
            super.layoutSublayers()

            emitterMode = .outline
            emitterShape = .line
            emitterSize = CGSize(width: frame.size.width, height: 1.0)
            emitterPosition = CGPoint(x: frame.size.width / 2.0, y: 0)
        }
    }
}

// MARK: - CAAnimationDelegate

extension ConfettiView: CAAnimationDelegate {
    public func animationDidStop(_ animation: CAAnimation, finished flag: Bool) {
        if let layer = animation.value(forKey: kAnimationLayerKey) as? CALayer {
            layer.removeAllAnimations()
            layer.removeFromSuperlayer()
        }
    }
}

// MARK: -

fileprivate extension ConfettiView.Content.Shape {
    func path(in rect: CGRect) -> CGPath {
        switch self {
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case .triangle:
            let path = CGMutablePath()
            path.addLines(between: [
                CGPoint(x: rect.midX, y: 0),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.midX, y: 0)
            ])

            return path
        case .square:
            return CGPath(rect: rect, transform: nil)
        case .custom(let path):
            return path
        }
    }

    func image(with color: UIColor) -> UIImage {
        let rect = CGRect(origin: .zero, size: CGSize(width: 12.0, height: 12.0))
        return UIGraphicsImageRenderer(size: rect.size).image { context in
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.addPath(path(in: rect))
            context.cgContext.fillPath()
        }
    }
}

fileprivate extension ConfettiView.Content {
    var color: UIColor? {
        switch self {
        case let .image(_, color?),
             let .shape(_, color):
            return color
        default:
            return nil
        }
    }

    var image: UIImage {
        switch self {
        case let .shape(shape, _):
            return shape.image(with: .white)
        case let .image(image, _):
            return image
        case let .text(string):
            let defaultAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16.0)
            ]

            return NSAttributedString(string: "\(string)", attributes: defaultAttributes).image()
        }
    }
}

fileprivate extension NSAttributedString {
    func image() -> UIImage {
        return UIGraphicsImageRenderer(size: size()).image { _ in
            self.draw(at: .zero)
        }
    }
}
