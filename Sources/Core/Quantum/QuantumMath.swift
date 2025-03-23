import Accelerate
import Foundation

/// Advanced quantum mathematics utilities for scientific calculations
struct QuantumMath {
    // MARK: - Physical Constants

    /// Planck constant (h) in J·s
    static let planckConstant: Double = 6.62607015e-34

    /// Reduced Planck constant (ħ = h/2π) in J·s
    static let reducedPlanckConstant: Double = 1.054571817e-34

    /// Speed of light (c) in m/s
    static let speedOfLight: Double = 299792458.0

    /// Electron mass in kg
    static let electronMass: Double = 9.1093837e-31

    /// Proton mass in kg
    static let protonMass: Double = 1.67262192e-27

    /// Electron charge in C
    static let elementaryCharge: Double = 1.602176634e-19

    /// Bohr radius in m
    static let bohrRadius: Double = 5.29177210903e-11

    /// Rydberg constant in m^-1
    static let rydbergConstant: Double = 1.0973731568160e7

    /// Rydberg energy in J
    static let rydbergEnergy: Double = 2.1798723611035e-18

    /// Boltzmann constant in J/K
    static let boltzmannConstant: Double = 1.380649e-23

    /// Vacuum permittivity (ε₀) in F/m
    static let vacuumPermittivity: Double = 8.8541878128e-12

    /// Planck length in m
    static let planckLength: Double = 1.616255e-35

    /// Planck time in s
    static let planckTime: Double = 5.39116e-44

    // MARK: - Quantum Wave Functions

    /// Calculate free particle wave function
    /// - Parameters:
    ///   - x: Position in meters
    ///   - k: Wave number in m^-1
    ///   - t: Time in seconds
    ///   - mass: Particle mass in kg
    /// - Returns: Complex wave function value (real, imaginary)
    static func freeParticleWaveFunction(x: Double, k: Double, t: Double, mass: Double) -> (
        real: Double, imaginary: Double
    ) {
        let omega = reducedPlanckConstant * k * k / (2 * mass)
        let phase = k * x - omega * t
        return (cos(phase), sin(phase))
    }

    /// Calculate Gaussian wave packet
    /// - Parameters:
    ///   - x: Position in meters
    ///   - x0: Initial packet center in meters
    ///   - k0: Central wave number in m^-1
    ///   - sigma: Spatial width of packet in meters
    ///   - t: Time in seconds
    ///   - mass: Particle mass in kg
    /// - Returns: Complex wave function value (real, imaginary)
    static func gaussianWavePacket(
        x: Double, x0: Double, k0: Double, sigma: Double, t: Double, mass: Double
    ) -> (real: Double, imaginary: Double) {
        // Time-dependent width
        let sigma_t = sigma * sqrt(1 + pow(reducedPlanckConstant * t / (mass * sigma * sigma), 2))

        // Spatial term
        let dx = x - x0 - (reducedPlanckConstant * k0 * t / mass)
        let spatial =
            exp(-dx * dx / (2 * sigma_t * sigma_t)) / pow(2 * Double.pi * sigma_t * sigma_t, 0.25)

        // Phase term
        let phase1 = k0 * dx
        let phase2 = atan(reducedPlanckConstant * t / (2 * mass * sigma * sigma))
        let phase = phase1 - phase2 / 2

        return (spatial * cos(phase), spatial * sin(phase))
    }

    /// Calculate infinite square well (particle in a box) wave function
    /// - Parameters:
    ///   - x: Position in meters
    ///   - L: Width of well in meters
    ///   - n: Quantum number (1, 2, 3, ...)
    ///   - t: Time in seconds
    ///   - mass: Particle mass in kg
    /// - Returns: Complex wave function value (real, imaginary)
    static func infiniteSquareWell(x: Double, L: Double, n: Int, t: Double, mass: Double) -> (
        real: Double, imaginary: Double
    ) {
        guard x >= 0 && x <= L else {
            return (0, 0)  // Outside the well
        }

        // Spatial part (normalized)
        let amplitude = sqrt(2 / L) * sin(Double(n) * Double.pi * x / L)

        // Energy (E_n = n²π²ħ²/(2mL²))
        let energy = pow(Double(n) * Double.pi * reducedPlanckConstant, 2) / (2 * mass * L * L)

        // Time evolution (e^(-iEt/ħ))
        let phase = -energy * t / reducedPlanckConstant

        return (amplitude * cos(phase), amplitude * sin(phase))
    }

    /// Calculate quantum harmonic oscillator wave function
    /// - Parameters:
    ///   - x: Position in meters
    ///   - n: Energy level (0, 1, 2, ...)
    ///   - omega: Angular frequency in rad/s
    ///   - t: Time in seconds
    ///   - mass: Particle mass in kg
    /// - Returns: Complex wave function value (real, imaginary)
    static func harmonicOscillator(x: Double, n: Int, omega: Double, t: Double, mass: Double) -> (
        real: Double, imaginary: Double
    ) {
        // Characteristic length
        let alpha = sqrt(mass * omega / reducedPlanckConstant)
        let xScaled = alpha * x

        // Calculate Hermite polynomial
        let hermite = hermitePolynomial(n: n, x: xScaled)

        // Normalization factor
        let normalization =
            1.0 / sqrt(pow(2, Double(n)) * factorial(n) * sqrt(Double.pi)) * pow(alpha, 0.25)

        // Spatial part
        let amplitude = normalization * hermite * exp(-xScaled * xScaled / 2)

        // Energy (E_n = (n+1/2)ħω)
        let energy = reducedPlanckConstant * omega * (Double(n) + 0.5)

        // Time evolution
        let phase = -energy * t / reducedPlanckConstant

        return (amplitude * cos(phase), amplitude * sin(phase))
    }

    /// Calculate hydrogen atom wave function (radial part only)
    /// - Parameters:
    ///   - r: Radial distance in meters
    ///   - n: Principal quantum number
    ///   - l: Angular momentum quantum number
    ///   - t: Time in seconds
    /// - Returns: Complex wave function value (real, imaginary)
    static func hydrogenAtomRadial(r: Double, n: Int, l: Int, t: Double) -> (
        real: Double, imaginary: Double
    ) {
        guard l < n && l >= 0 else {
            return (0, 0)  // Invalid quantum numbers
        }

        // Bohr radius (a₀)
        let a0 = bohrRadius

        // Normalized radius
        let rho = 2 * r / (Double(n) * a0)

        // Associated Laguerre polynomial
        let laguerrePoly = associatedLaguerre(n: n - l - 1, alpha: 2 * l + 1, x: rho)

        // Radial wave function (without angular part)
        let normalization = sqrt(
            pow(2.0 / (Double(n) * a0), 3) * factorial(n - l - 1)
                / (2 * Double(n) * factorial(n + l))
        )

        let radial = normalization * exp(-rho / 2) * pow(rho, Double(l)) * laguerrePoly

        // Energy (E_n = -R_y/n²)
        let energy = -rydbergEnergy / pow(Double(n), 2)

        // Time evolution
        let phase = -energy * t / reducedPlanckConstant

        return (radial * cos(phase), radial * sin(phase))
    }

    // MARK: - Expectation Values

    /// Calculate expectation value of position for a wave function
    /// - Parameters:
    ///   - waveFunction: Array of complex wave function values
    ///   - positions: Array of position values
    /// - Returns: Expectation value of position
    static func expectationPosition(
        waveFunction: [(real: Double, imaginary: Double)], positions: [Double]
    ) -> Double {
        guard waveFunction.count == positions.count && !waveFunction.isEmpty else {
            return 0
        }

        // Calculate probability density
        let probabilities = waveFunction.map { $0.real * $0.real + $0.imaginary * $0.imaginary }

        // Calculate weighted sum
        var sum = 0.0
        var normalization = 0.0

        for i in 0..<positions.count {
            sum += positions[i] * probabilities[i]
            normalization += probabilities[i]
        }

        return normalization > 0 ? sum / normalization : 0
    }

    /// Calculate expectation value of momentum for a wave function
    /// - Parameters:
    ///   - waveFunction: Array of complex wave function values
    ///   - positions: Array of position values
    /// - Returns: Expectation value of momentum
    static func expectationMomentum(
        waveFunction: [(real: Double, imaginary: Double)], positions: [Double]
    ) -> Double {
        guard waveFunction.count == positions.count && waveFunction.count > 2 else {
            return 0
        }

        // Calculate spatial derivative of wave function (∂ψ/∂x)
        var derivativeReal = [Double](repeating: 0, count: waveFunction.count)
        var derivativeImag = [Double](repeating: 0, count: waveFunction.count)

        for i in 1..<(waveFunction.count - 1) {
            let dx = positions[i + 1] - positions[i - 1]
            derivativeReal[i] = (waveFunction[i + 1].real - waveFunction[i - 1].real) / dx
            derivativeImag[i] = (waveFunction[i + 1].imaginary - waveFunction[i - 1].imaginary) / dx
        }

        // Handle boundaries with forward/backward differences
        let dx1 = positions[1] - positions[0]
        derivativeReal[0] = (waveFunction[1].real - waveFunction[0].real) / dx1
        derivativeImag[0] = (waveFunction[1].imaginary - waveFunction[0].imaginary) / dx1

        let dxn = positions[positions.count - 1] - positions[positions.count - 2]
        derivativeReal[positions.count - 1] =
            (waveFunction[positions.count - 1].real - waveFunction[positions.count - 2].real) / dxn
        derivativeImag[positions.count - 1] =
            (waveFunction[positions.count - 1].imaginary
                - waveFunction[positions.count - 2].imaginary) / dxn

        // Calculate <p> = -iħ⟨ψ|∂/∂x|ψ⟩
        var sum = 0.0
        var normalization = 0.0

        for i in 0..<positions.count {
            // ψ* · (∂ψ/∂x)
            let integrand =
                (waveFunction[i].real * derivativeImag[i] - waveFunction[i].imaginary
                    * derivativeReal[i])

            // |ψ|²
            let probability =
                waveFunction[i].real * waveFunction[i].real + waveFunction[i].imaginary
                * waveFunction[i].imaginary

            sum += integrand
            normalization += probability
        }

        // Apply -iħ factor and normalize
        return normalization > 0 ? -reducedPlanckConstant * sum / normalization : 0
    }

    /// Calculate expectation value of energy for a wave function
    /// - Parameters:
    ///   - waveFunction: Array of complex wave function values
    ///   - positions: Array of position values
    ///   - potential: Array of potential energy values
    ///   - mass: Particle mass
    /// - Returns: Expectation value of energy
    static func expectationEnergy(
        waveFunction: [(real: Double, imaginary: Double)], positions: [Double], potential: [Double],
        mass: Double
    ) -> Double {
        guard
            waveFunction.count == positions.count && positions.count == potential.count
                && waveFunction.count > 2
        else {
            return 0
        }

        // Calculate second spatial derivative (∂²ψ/∂x²)
        var secondDerivReal = [Double](repeating: 0, count: waveFunction.count)
        var secondDerivImag = [Double](repeating: 0, count: waveFunction.count)

        for i in 1..<(waveFunction.count - 1) {
            // Calculate positions for left and right points
            let dxL = positions[i] - positions[i - 1]
            let dxR = positions[i + 1] - positions[i]

            // Use central difference approximation
            secondDerivReal[i] =
                2 * (waveFunction[i + 1].real - 2 * waveFunction[i].real + waveFunction[i - 1].real)
                / (dxL * dxR)
            secondDerivImag[i] =
                2
                * (waveFunction[i + 1].imaginary - 2 * waveFunction[i].imaginary
                    + waveFunction[i - 1].imaginary) / (dxL * dxR)
        }

        // Handle boundaries (use one-sided approximations or extend with zero values)
        secondDerivReal[0] = 0
        secondDerivImag[0] = 0
        secondDerivReal[positions.count - 1] = 0
        secondDerivImag[positions.count - 1] = 0

        // Calculate kinetic and potential energy contributions
        var kineticSum = 0.0
        var potentialSum = 0.0
        var normalization = 0.0

        for i in 0..<positions.count {
            // |ψ|²
            let probability =
                waveFunction[i].real * waveFunction[i].real + waveFunction[i].imaginary
                * waveFunction[i].imaginary

            // Kinetic energy term: -ħ²/2m · (∂²ψ/∂x²)
            let kinetic =
                -reducedPlanckConstant * reducedPlanckConstant / (2 * mass)
                * (waveFunction[i].real * secondDerivReal[i] + waveFunction[i].imaginary
                    * secondDerivImag[i])

            // Potential energy term: V(x) · |ψ|²
            let potentialTerm = potential[i] * probability

            kineticSum += kinetic
            potentialSum += potentialTerm
            normalization += probability
        }

        if normalization > 0 {
            let avgKinetic = kineticSum / normalization
            let avgPotential = potentialSum / normalization
            return avgKinetic + avgPotential
        }

        return 0
    }

    /// Calculate uncertainty in position
    static func uncertaintyPosition(
        waveFunction: [(real: Double, imaginary: Double)], positions: [Double]
    ) -> Double {
        guard waveFunction.count == positions.count && !waveFunction.isEmpty else {
            return 0
        }

        // Calculate expectation value of position
        let expX = expectationPosition(waveFunction: waveFunction, positions: positions)

        // Calculate <x²>
        let probabilities = waveFunction.map { $0.real * $0.real + $0.imaginary * $0.imaginary }

        var sum = 0.0
        var normalization = 0.0

        for i in 0..<positions.count {
            sum += positions[i] * positions[i] * probabilities[i]
            normalization += probabilities[i]
        }

        let expX2 = normalization > 0 ? sum / normalization : 0

        // Uncertainty: Δx = sqrt(<x²> - <x>²)
        return sqrt(max(0, expX2 - expX * expX))
    }

    /// Calculate uncertainty in momentum
    static func uncertaintyMomentum(
        waveFunction: [(real: Double, imaginary: Double)], positions: [Double]
    ) -> Double {
        guard waveFunction.count == positions.count && waveFunction.count > 2 else {
            return 0
        }

        // Calculate expectation value of momentum
        let expP = expectationMomentum(waveFunction: waveFunction, positions: positions)

        // Calculate wave function derivative
        var derivativeReal = [Double](repeating: 0, count: waveFunction.count)
        var derivativeImag = [Double](repeating: 0, count: waveFunction.count)

        for i in 1..<(waveFunction.count - 1) {
            let dx = positions[i + 1] - positions[i - 1]
            derivativeReal[i] = (waveFunction[i + 1].real - waveFunction[i - 1].real) / dx
            derivativeImag[i] = (waveFunction[i + 1].imaginary - waveFunction[i - 1].imaginary) / dx
        }

        // Handle boundaries
        let dx1 = positions[1] - positions[0]
        derivativeReal[0] = (waveFunction[1].real - waveFunction[0].real) / dx1
        derivativeImag[0] = (waveFunction[1].imaginary - waveFunction[0].imaginary) / dx1

        let dxn = positions[positions.count - 1] - positions[positions.count - 2]
        derivativeReal[positions.count - 1] =
            (waveFunction[positions.count - 1].real - waveFunction[positions.count - 2].real) / dxn
        derivativeImag[positions.count - 1] =
            (waveFunction[positions.count - 1].imaginary
                - waveFunction[positions.count - 2].imaginary) / dxn

        // Calculate <p²> = -ħ²⟨ψ|∂²/∂x²|ψ⟩
        // We approximate this using the first derivative squared
        var sum = 0.0
        var normalization = 0.0

        for i in 0..<positions.count {
            // |∂ψ/∂x|²
            let derivSquared =
                derivativeReal[i] * derivativeReal[i] + derivativeImag[i] * derivativeImag[i]

            // |ψ|²
            let probability =
                waveFunction[i].real * waveFunction[i].real + waveFunction[i].imaginary
                * waveFunction[i].imaginary

            sum += derivSquared
            normalization += probability
        }

        // Apply -ħ² factor and normalize to get <p²>
        let expP2 =
            normalization > 0
            ? reducedPlanckConstant * reducedPlanckConstant * sum / normalization : 0

        // Uncertainty: Δp = sqrt(<p²> - <p>²)
        return sqrt(max(0, expP2 - expP * expP))
    }

    /// Calculate expectation value of momentum squared (<p²>)
    static func expectationMomentumSquared(
        waveFunction: [(real: Double, imaginary: Double)], positions: [Double], mass: Double
    ) -> Double {
        guard waveFunction.count == positions.count && waveFunction.count > 2 else {
            return 0
        }

        var sum = 0.0
        var normalization = 0.0

        for i in 1..<(waveFunction.count - 1) {
            // Calculate positions for left and right points
            let dxL = positions[i] - positions[i - 1]
            let dxR = positions[i + 1] - positions[i]

            // Use central difference approximation
            let derivativeReal = (waveFunction[i + 1].real - waveFunction[i - 1].real) / (dxL + dxR)
            let derivativeImag =
                (waveFunction[i + 1].imaginary - waveFunction[i - 1].imaginary) / (dxL + dxR)

            // |∂ψ/∂x|²
            let derivSquared =
                derivativeReal * derivativeReal + derivativeImag * derivativeImag

            // |ψ|²
            let probability =
                waveFunction[i].real * waveFunction[i].real + waveFunction[i].imaginary
                * waveFunction[i].imaginary

            sum += derivSquared
            normalization += probability
        }

        // Apply -ħ² factor and normalize to get <p²>
        return normalization > 0
            ? reducedPlanckConstant * reducedPlanckConstant * sum / normalization : 0
    }

    // MARK: - Utility Functions

    /// Calculate Hermite polynomial using recurrence relation
    /// - Parameters:
    ///   - n: Order of polynomial (0, 1, 2, ...)
    ///   - x: Value to evaluate at
    /// - Returns: Value of Hermite polynomial H_n(x)
    static func hermitePolynomial(n: Int, x: Double) -> Double {
        guard n >= 0 else { return 0 }

        if n == 0 {
            return 1
        }

        if n == 1 {
            return 2 * x
        }

        // Use recursion formula: H_{n+1}(x) = 2x H_n(x) - 2n H_{n-1}(x)
        var h_prev = 1.0
        var h_curr = 2 * x

        for i in 1..<n {
            let h_next = 2 * x * h_curr - 2 * Double(i) * h_prev
            h_prev = h_curr
            h_curr = h_next
        }

        return h_curr
    }

    /// Calculate Associated Laguerre polynomial
    /// - Parameters:
    ///   - n: Order of polynomial
    ///   - alpha: Parameter alpha
    ///   - x: Value to evaluate at
    /// - Returns: Value of associated Laguerre polynomial L_n^alpha(x)
    static func associatedLaguerre(n: Int, alpha: Int, x: Double) -> Double {
        guard n >= 0 else { return 0 }

        if n == 0 {
            return 1
        }

        if n == 1 {
            return 1 + Double(alpha) - x
        }

        // Use recursion formula
        var l_prev = 1.0
        var l_curr = 1 + Double(alpha) - x

        for i in 1..<n {
            let j = Double(i)
            let a = Double(alpha)
            let l_next = ((2 * j + 1 + a - x) * l_curr - (j + a) * l_prev) / (j + 1)
            l_prev = l_curr
            l_curr = l_next
        }

        return l_curr
    }

    /// Calculate factorial
    /// - Parameter n: Integer value
    /// - Returns: Factorial of n
    static func factorial(_ n: Int) -> Double {
        guard n >= 0 else { return 0 }

        var result = 1.0
        for i in 2...n {
            result *= Double(i)
        }
        return result
    }

    /// Convert between energy and frequency
    /// - Parameter energy: Energy in Joules
    /// - Returns: Frequency in Hz
    static func energyToFrequency(energy: Double) -> Double {
        return energy / planckConstant
    }

    /// Convert between frequency and energy
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Energy in Joules
    static func frequencyToEnergy(frequency: Double) -> Double {
        return frequency * planckConstant
    }

    /// Convert between energy and wavelength
    /// - Parameter energy: Energy in Joules
    /// - Returns: Wavelength in meters
    static func energyToWavelength(energy: Double) -> Double {
        return speedOfLight * planckConstant / energy
    }

    /// Calculate de Broglie wavelength
    /// - Parameters:
    ///   - momentum: Momentum in kg·m/s
    /// - Returns: de Broglie wavelength in meters
    static func deBroglieWavelength(momentum: Double) -> Double {
        return planckConstant / momentum
    }

    /// Calculate de Broglie wavelength from mass and velocity
    /// - Parameters:
    ///   - mass: Particle mass in kg
    ///   - velocity: Particle velocity in m/s
    /// - Returns: de Broglie wavelength in meters
    static func deBroglieWavelength(mass: Double, velocity: Double) -> Double {
        return planckConstant / (mass * velocity)
    }

    /// Calculate quantum mechanical energy levels for a particle in a box
    /// - Parameters:
    ///   - n: Energy level (quantum number)
    ///   - L: Box length in meters
    ///   - mass: Particle mass in kg
    /// - Returns: Energy in Joules
    static func particleInBoxEnergy(n: Int, L: Double, mass: Double) -> Double {
        // Break down the complex expression
        let n_squared = Double(n * n)
        let pi_squared = Double.pi * Double.pi
        let hbar_squared = reducedPlanckConstant * reducedPlanckConstant
        let denominator = 2.0 * mass * L * L

        // Calculate energy
        return (n_squared * pi_squared * hbar_squared) / denominator
    }

    /// Calculate quantum harmonic oscillator energy levels
    /// - Parameters:
    ///   - n: Energy level (quantum number)
    ///   - omega: Angular frequency in rad/s
    /// - Returns: Energy in Joules
    static func harmonicOscillatorEnergy(n: Int, omega: Double) -> Double {
        return reducedPlanckConstant * omega * (Double(n) + 0.5)
    }

    /// Calculate hydrogen atom energy levels
    /// - Parameter n: Principal quantum number
    /// - Returns: Energy in Joules
    static func hydrogenAtomEnergy(n: Int) -> Double {
        guard n > 0 else { return 0 }
        return -rydbergEnergy / Double(n * n)
    }

    /// Convert Joules to electron volts
    /// - Parameter joules: Energy in Joules
    /// - Returns: Energy in eV
    static func jouleToElectronVolt(joules: Double) -> Double {
        return joules / elementaryCharge
    }

    /// Convert electron volts to Joules
    /// - Parameter eV: Energy in eV
    /// - Returns: Energy in Joules
    static func electronVoltToJoule(eV: Double) -> Double {
        return eV * elementaryCharge
    }

    /// Calculate transmission coefficient for quantum tunneling through a rectangular barrier
    /// - Parameters:
    ///   - energy: Particle energy in Joules
    ///   - barrierHeight: Barrier height in Joules
    ///   - barrierWidth: Barrier width in meters
    ///   - mass: Particle mass in kg
    /// - Returns: Transmission coefficient (0 to 1)
    static func quantumTunnelingTransmission(
        energy: Double, barrierHeight: Double, barrierWidth: Double, mass: Double
    ) -> Double {
        guard energy < barrierHeight else {
            // Above barrier (classical regime, but with quantum reflection)
            let k1 = sqrt(2 * mass * energy) / reducedPlanckConstant
            let k2 = sqrt(2 * mass * (barrierHeight - energy)) / reducedPlanckConstant
            let factor = 4 * k1 * k2 / pow(k1 + k2, 2)
            return factor
        }

        // Below barrier (tunneling)
        let kappa = sqrt(2 * mass * (barrierHeight - energy)) / reducedPlanckConstant

        // Transmission coefficient using simple approximation: T ≈ e^(-2κL)
        let exponent = -2 * kappa * barrierWidth
        let _ = exp(exponent)

        // More accurate formula for low tunneling:
        let E = energy
        let V0 = barrierHeight
        let denominator =
            1 + (pow(V0, 2) * sinh(kappa * barrierWidth) * sinh(kappa * barrierWidth))
            / (4 * E * (V0 - E))

        return 1 / denominator
    }

    /// Calculate uncertainty relation product Δx·Δp
    /// - Parameters:
    ///   - deltaX: Uncertainty in position
    ///   - deltaP: Uncertainty in momentum
    /// - Returns: Uncertainty relation product (should be ≥ ħ/2)
    static func uncertaintyRelation(deltaX: Double, deltaP: Double) -> Double {
        return deltaX * deltaP
    }

    /// Check if uncertainty relation is satisfied
    /// - Parameters:
    ///   - deltaX: Uncertainty in position
    ///   - deltaP: Uncertainty in momentum
    /// - Returns: True if Δx·Δp ≥ ħ/2
    static func isUncertaintyRelationSatisfied(deltaX: Double, deltaP: Double) -> Bool {
        return uncertaintyRelation(deltaX: deltaX, deltaP: deltaP) >= reducedPlanckConstant / 2
    }
}
