import Foundation

/// A structure representing a complex number with real and imaginary components.
/// This is the central implementation to be used throughout the app.
public struct Complex: Equatable, Hashable, Codable {
    public var real: Double
    public var imaginary: Double

    /// Initialize a complex number with real and imaginary parts
    public init(real: Double = 0.0, imaginary: Double = 0.0) {
        self.real = real
        self.imaginary = imaginary
    }

    /// Return the magnitude (absolute value) of the complex number
    public var magnitude: Double {
        return sqrt(real * real + imaginary * imaginary)
    }

    /// Return the phase (argument) of the complex number
    public var phase: Double {
        return atan2(imaginary, real)
    }

    /// Return the square of the magnitude
    public var absoluteSquared: Double {
        return real * real + imaginary * imaginary
    }

    /// Return the complex conjugate
    public var conjugate: Complex {
        return Complex(real: real, imaginary: -imaginary)
    }

    /// Addition of two complex numbers
    public static func + (lhs: Complex, rhs: Complex) -> Complex {
        return Complex(
            real: lhs.real + rhs.real,
            imaginary: lhs.imaginary + rhs.imaginary
        )
    }

    /// Subtraction of two complex numbers
    public static func - (lhs: Complex, rhs: Complex) -> Complex {
        return Complex(
            real: lhs.real - rhs.real,
            imaginary: lhs.imaginary - rhs.imaginary
        )
    }

    /// Multiplication of two complex numbers
    public static func * (lhs: Complex, rhs: Complex) -> Complex {
        return Complex(
            real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
            imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        )
    }

    /// Multiplication of a complex number by a scalar
    public static func * (lhs: Double, rhs: Complex) -> Complex {
        return Complex(
            real: lhs * rhs.real,
            imaginary: lhs * rhs.imaginary
        )
    }

    /// Division of two complex numbers
    public static func / (lhs: Complex, rhs: Complex) -> Complex {
        let denominator = rhs.real * rhs.real + rhs.imaginary * rhs.imaginary
        return Complex(
            real: (lhs.real * rhs.real + lhs.imaginary * rhs.imaginary) / denominator,
            imaginary: (lhs.imaginary * rhs.real - lhs.real * rhs.imaginary) / denominator
        )
    }

    /// Complex exponential
    public static func exp(_ z: Complex) -> Complex {
        let expReal = Foundation.exp(z.real)
        return Complex(
            real: expReal * cos(z.imaginary),
            imaginary: expReal * sin(z.imaginary)
        )
    }

    /// Creates a complex number from polar coordinates
    public static func fromPolar(r: Double, theta: Double) -> Complex {
        return Complex(
            real: r * cos(theta),
            imaginary: r * sin(theta)
        )
    }

    /// Returns a string representation of the complex number
    public var description: String {
        if imaginary >= 0 {
            return "\(real) + \(imaginary)i"
        } else {
            return "\(real) - \(abs(imaginary))i"
        }
    }

    /// Conversion to Metal-compatible float-based Complex type
    public var metalComplex: (Float, Float) {
        return (Float(real), Float(imaginary))
    }
}
