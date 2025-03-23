//
//  QuantumSimulator.swift
//  QwantumWaveform
//
//  Created by HAWZHIN on 16/03/2025.
//

// Source/Models/QuantumSimulator.swift

import Accelerate
import Foundation

class QuantumSimulator {
    // Physical constants
    private let hBar = 1.054571817e-34  // Reduced Planck constant (J·s)
    private let electronMass = 9.1093837e-31  // Electron mass (kg)
    private let electronCharge = 1.602176634e-19  // Elementary charge (C)
    private let vacuumPermittivity = 8.8541878128e-12  // Permittivity of free space (F/m)
    private let bohrRadius = 5.29177210903e-11  // Bohr radius (m)

    // Simulation parameters
    private var systemType: QuantumSystemType = .freeParticle
    private var particleMass: Double = 9.1093837e-31  // Default to electron mass
    private var energyLevel: Int = 1
    private var time: Double = 0.0  // Simulation time
    private var potentialHeight: Double = 0.0  // For barrier/well height

    // Spatial grid for simulation
    private var xMin: Double = -20e-9  // -20 nm
    private var xMax: Double = 20e-9  // 20 nm
    private var gridPoints: Int = 1000
    private var spatialGrid: [Double] = []

    // Cached calculation results
    private var cachedWaveFunction: [Complex] = []
    private var cachedProbabilityDensity: [Double] = []
    private var needsRecalculation: Bool = true

    // MARK: - Performance Optimization

    // Add cache storage for expensive calculations
    private var waveFunctionCache: [Double: (real: [Double], imaginary: [Double])] = [:]
    private var phaseCache: [Double: [Double]] = [:]
    private var probabilityCache: [Double: [Double]] = [:]

    // Maximum size for caches to prevent memory issues
    private let maxCacheSize = 100
    private var cacheTimes: [Double] = []

    // Add a flag for dirty state that requires recalculation
    private var isDirty = true
    private var lastCalculationTime: Double = 0

    // Add time step tracking
    private var currentTime: Double = 0
    private var timeStepSize: Double = 0.05
    private var isAnimating: Bool = false

    // SIMD optimization configuration
    private let useSIMDAcceleration = true

    // Add cache for wavelength calculations
    private var wavelengthCache: Double?

    // MARK: - Accelerate Framework Optimization

    /// Calculate probability density using Accelerate framework for better performance
    private func calculateProbabilityDensityAccelerated(real: [Double], imaginary: [Double])
        -> [Double]
    {
        let count = min(real.count, imaginary.count)
        var probabilities = [Double](repeating: 0.0, count: count)

        // Use Accelerate framework for faster computation
        // For each probability value: p = real² + imaginary²

        // Square real components: realSquared = real²
        var realSquared = [Double](repeating: 0.0, count: count)
        vDSP_vsqD(real, 1, &realSquared, 1, vDSP_Length(count))

        // Square imaginary components: imagSquared = imag²
        var imagSquared = [Double](repeating: 0.0, count: count)
        vDSP_vsqD(imaginary, 1, &imagSquared, 1, vDSP_Length(count))

        // Add squares: probability = realSquared + imagSquared
        vDSP_vaddD(realSquared, 1, imagSquared, 1, &probabilities, 1, vDSP_Length(count))

        // Normalize probabilities if needed
        let sum = vDSP.sum(probabilities)
        if sum > 0 {
            var scale = 1.0 / sum
            vDSP_vsmulD(probabilities, 1, &scale, &probabilities, 1, vDSP_Length(count))
        }

        return probabilities
    }

    /// Calculate probability density based on wave function
    private func calculateProbabilityDensity() {
        // Check cache first
        if let cached = probabilityCache[currentTime] {
            cachedProbabilityDensity = cached
            return
        }

        // Calculate from wave function if needed
        let (real, imaginary) = getWaveFunctionComponents()

        // Use Accelerate framework for better performance
        let probabilities = calculateProbabilityDensityAccelerated(real: real, imaginary: imaginary)

        // Cache the result
        probabilityCache[currentTime] = probabilities
        cacheTimePoint(currentTime)
        cachedProbabilityDensity = probabilities
    }

    /// Optimize de Broglie wavelength calculation
    func calculateDeBroglieWavelength() -> Double {
        // Cache the result for repeated calls
        if let cached = wavelengthCache {
            return cached
        }

        let result: Double

        switch systemType {
        case .freeParticle:
            // λ = h/p for a free particle with momentum p
            // For visualization, we use a moderate energy suitable for display
            let kineticEnergy = 10 * electronCharge  // ~10 eV
            let momentum = sqrt(2 * particleMass * kineticEnergy)
            result = hBar * 2 * Double.pi / momentum

        case .potentialWell:
            // λ = 2L/n for nth energy level in well of width L
            let wellWidth = xMax - xMin
            result = 2 * wellWidth / Double(energyLevel)

        case .harmonicOscillator:
            // Not a simple wavelength, but we can calculate characteristic length
            let springConstant = 1e-8  // Arbitrary for visualization
            let omega = sqrt(springConstant / particleMass)
            result = sqrt(hBar / (particleMass * omega))

        case .hydrogenAtom:
            // Use Bohr model: r_n = n²a₀ where a₀ is Bohr radius
            result = 2 * Double.pi * Double(energyLevel * energyLevel) * bohrRadius
        }

        // Cache the result
        wavelengthCache = result
        return result
    }

    init() {
        // Initialize spatial grid
        updateSpatialGrid()
    }

    // MARK: - Public Methods

    func setSystemType(_ type: QuantumSystemType) {
        systemType = type
        needsRecalculation = true

        // Adjust domain based on system type
        switch type {
        case .freeParticle:
            xMin = -20e-9  // -20 nm
            xMax = 20e-9  // 20 nm
        case .potentialWell:
            xMin = -10e-9  // -10 nm
            xMax = 10e-9  // 10 nm
        case .harmonicOscillator:
            xMin = -15e-9  // -15 nm
            xMax = 15e-9  // 15 nm
        case .hydrogenAtom:
            xMin = 0  // Start at origin for radial wavefunction
            xMax = 30 * bohrRadius  // ~15 nm
        }

        updateSpatialGrid()
    }

    func setParticleMass(_ mass: Double) {
        particleMass = mass
        needsRecalculation = true
    }

    func setEnergyLevel(_ level: Int) {
        energyLevel = max(1, level)  // Ensure level is at least 1
        needsRecalculation = true
    }

    func setTime(_ t: Double) {
        time = t
        needsRecalculation = true
    }

    func setPotentialHeight(_ height: Double) {
        potentialHeight = height
        needsRecalculation = true
    }

    func getSpatialGrid() -> [Double] {
        return spatialGrid
    }

    func getProbabilityDensityGrid() -> [Double] {
        if needsRecalculation {
            calculateWaveFunction()
        }
        return cachedProbabilityDensity
    }

    func getWaveFunction(at position: Double) -> Complex {
        let index = spatialGrid.firstIndex { abs($0 - position) < 1e-10 } ?? 0
        if needsRecalculation {
            calculateWaveFunction()
        }
        return index < cachedWaveFunction.count ? cachedWaveFunction[index] : Complex()
    }

    func getExpectedEnergy() -> Double {
        switch systemType {
        case .freeParticle:
            // E = p²/2m = (ħk)²/2m where k = 2π/λ
            let deBroglie = calculateDeBroglieWavelength()
            let k = 2 * Double.pi / deBroglie
            return (hBar * k) * (hBar * k) / (2 * particleMass)

        case .potentialWell:
            // E = (n²π²ħ²)/(2mL²) for infinite well of width L
            let wellWidth = xMax - xMin
            return Double(energyLevel * energyLevel) * Double.pi * Double.pi * hBar * hBar
                / (2 * particleMass * wellWidth * wellWidth)

        case .harmonicOscillator:
            // E = (n + 1/2)ħω where ω = √(k/m)
            // We use a nominal spring constant to visualize properly
            let springConstant = 1e-8  // Arbitrary for visualization
            let omega = sqrt(springConstant / particleMass)
            return (Double(energyLevel) - 0.5) * hBar * omega

        case .hydrogenAtom:
            // E = -Ry/n² where Ry is Rydberg energy
            let rydberg =
                electronMass * pow(electronCharge, 4)
                / (8 * pow(vacuumPermittivity, 2) * pow(hBar, 2))
            return -rydberg / Double(energyLevel * energyLevel)
        }
    }

    // MARK: - Private Methods

    private func updateSpatialGrid() {
        spatialGrid = stride(from: xMin, through: xMax, by: (xMax - xMin) / Double(gridPoints - 1))
            .map { $0 }
        needsRecalculation = true
    }

    private func calculateWaveFunction() {
        // Delegate to the more optimized version of this method
        let time = self.time
        _ = calculateWaveFunction(at: time)
        needsRecalculation = false
    }

    /// Calculate wave function using SIMD acceleration where possible
    private func calculateWaveFunction(at time: Double) -> (real: [Double], imaginary: [Double]) {
        // Check cache first
        if let cached = waveFunctionCache[time] {
            return cached
        }

        // Save current time
        let originalTime = self.time

        // Set time for calculation
        self.time = time

        // Initialize empty arrays if needed
        if cachedWaveFunction.isEmpty {
            cachedWaveFunction = Array(repeating: Complex(), count: spatialGrid.count)
            cachedProbabilityDensity = Array(repeating: 0.0, count: spatialGrid.count)
        }

        // Calculate wave function based on system type
        switch systemType {
        case .freeParticle:
            calculateFreeParticleWaveFunction()
        case .potentialWell:
            calculatePotentialWellWaveFunction()
        case .harmonicOscillator:
            calculateHarmonicOscillatorWaveFunction()
        case .hydrogenAtom:
            calculateHydrogenAtomWaveFunction()
        }

        // Calculate probability density
        for i in 0..<cachedWaveFunction.count {
            cachedProbabilityDensity[i] = cachedWaveFunction[i].absoluteSquared
        }

        // Normalize probability density
        let sum = cachedProbabilityDensity.reduce(0, +)
        if sum > 0 {
            for i in 0..<cachedProbabilityDensity.count {
                cachedProbabilityDensity[i] /= sum
            }
        }

        // Extract components with SIMD optimization if enabled
        var realComponents: [Double] = []
        var imaginaryComponents: [Double] = []

        if useSIMDAcceleration && cachedWaveFunction.count >= 4 {
            // Process in SIMD chunks (4 elements at a time)
            let count = cachedWaveFunction.count
            realComponents = [Double](repeating: 0.0, count: count)
            imaginaryComponents = [Double](repeating: 0.0, count: count)

            // Process 4 elements at a time with SIMD
            let simdCount = count / 4 * 4
            for i in stride(from: 0, to: simdCount, by: 4) {
                var realVector = SIMD4<Double>(0, 0, 0, 0)
                var imagVector = SIMD4<Double>(0, 0, 0, 0)

                // Load values into SIMD vectors
                for j in 0..<4 {
                    realVector[j] = cachedWaveFunction[i + j].real
                    imagVector[j] = cachedWaveFunction[i + j].imaginary
                }

                // Store back to arrays
                for j in 0..<4 {
                    realComponents[i + j] = realVector[j]
                    imaginaryComponents[i + j] = imagVector[j]
                }
            }

            // Handle remaining elements
            for i in simdCount..<count {
                realComponents[i] = cachedWaveFunction[i].real
                imaginaryComponents[i] = cachedWaveFunction[i].imaginary
            }
        } else {
            // Fall back to standard approach
            for complex in cachedWaveFunction {
                realComponents.append(complex.real)
                imaginaryComponents.append(complex.imaginary)
            }
        }

        // Restore original time
        self.time = originalTime

        // Cache the result
        waveFunctionCache[time] = (real: realComponents, imaginary: imaginaryComponents)
        probabilityCache[time] = cachedProbabilityDensity
        cacheTimePoint(time)

        // Return result
        return (real: realComponents, imaginary: imaginaryComponents)
    }

    private func calculateFreeParticleWaveFunction() {
        let k = 2 * Double.pi / calculateDeBroglieWavelength()
        let energy = getExpectedEnergy()
        let omega = energy / hBar

        // Create a Gaussian wave packet centered at x0
        let x0 = xMin + (xMax - xMin) * 0.25  // Center at 1/4 of the range
        let sigma = (xMax - xMin) * 0.05  // Width of the packet

        for i in 0..<spatialGrid.count {
            let x = spatialGrid[i]

            // Gaussian envelope
            let envelope = exp(-pow(x - x0, 2) / (2 * sigma * sigma))

            // Phase factor e^i(kx - ωt)
            let phase = k * x - omega * time
            let real = envelope * cos(phase)
            let imaginary = envelope * sin(phase)

            cachedWaveFunction[i] = Complex(real: real, imaginary: imaginary)
        }

        // If there's a potential barrier
        if potentialHeight > 0 {
            // Apply quantum tunneling effect
            let barrierPosition = (xMax - xMin) * 0.6 + xMin  // Barrier at 60% of range
            let barrierWidth = (xMax - xMin) * 0.05  // 5% of range

            // Convert eV to Joules
            let potentialEnergyJ = potentialHeight * electronCharge

            for i in 0..<spatialGrid.count {
                let x = spatialGrid[i]

                // If inside barrier
                if x > barrierPosition && x < barrierPosition + barrierWidth {
                    // Calculate tunneling amplitude (simplified)
                    let kappa = sqrt(2 * particleMass * (potentialEnergyJ - energy)) / hBar
                    if potentialEnergyJ > energy {
                        // Barrier higher than energy - tunneling
                        let distance = x - barrierPosition
                        let attenuation = exp(-kappa * distance)
                        cachedWaveFunction[i].real *= attenuation
                        cachedWaveFunction[i].imaginary *= attenuation
                    }
                }
                // If past barrier
                else if x >= barrierPosition + barrierWidth {
                    // Transmitted wave has reduced amplitude
                    let transmissionRatio = energy / potentialEnergyJ
                    if transmissionRatio < 1.0 {
                        let transmissionAmplitude = sqrt(transmissionRatio)
                        cachedWaveFunction[i].real *= transmissionAmplitude
                        cachedWaveFunction[i].imaginary *= transmissionAmplitude
                    }
                }
            }
        }
    }

    private func calculatePotentialWellWaveFunction() {
        // For infinite well, wave function is sine waves
        // ψ_n(x) = √(2/L) * sin(nπx/L) for x in [0,L]

        let wellWidth = xMax - xMin
        let normalization = sqrt(2.0 / wellWidth)

        for i in 0..<spatialGrid.count {
            let x = spatialGrid[i]

            // Map x to [0,L] range
            let xNormalized = (x - xMin) / wellWidth

            if xNormalized >= 0 && xNormalized <= 1 {
                // Inside the well
                let value = normalization * sin(Double.pi * Double(energyLevel) * xNormalized)

                // Add time dependence
                let energy = getExpectedEnergy()
                let omega = energy / hBar
                let timeFactor = omega * time

                let real = value * cos(-timeFactor)
                let imaginary = value * sin(-timeFactor)

                cachedWaveFunction[i] = Complex(real: real, imaginary: imaginary)
            } else {
                // Outside the well (zero)
                cachedWaveFunction[i] = Complex(real: 0, imaginary: 0)
            }
        }
    }

    private func calculateHarmonicOscillatorWaveFunction() {
        // Harmonic oscillator solutions use Hermite polynomials
        // We'll use a simplified approach for visualization

        // Calculate characteristic parameters
        let springConstant = 1e-8  // Arbitrary for visualization
        let omega = sqrt(springConstant / particleMass)
        let alpha = sqrt(particleMass * omega / hBar)

        // Get energy for time evolution
        let energy = getExpectedEnergy()
        let timeFactor = energy * time / hBar

        for i in 0..<spatialGrid.count {
            let x = spatialGrid[i]

            // Gaussian factor common to all states
            let gaussianFactor = exp(-alpha * x * x / 2)

            // Value depends on energy level (using Hermite polynomials)
            var value = gaussianFactor

            // Multiply by appropriate Hermite polynomial for energy level
            switch energyLevel {
            case 1:
                // Ground state: H_0(x) = 1
                value *= 1.0
            case 2:
                // First excited state: H_1(x) = 2x
                value *= 2.0 * alpha * x
            case 3:
                // Second excited state: H_2(x) = 4x² - 2
                let ax = alpha * x
                value *= 4.0 * ax * ax - 2.0
            case 4:
                // Third excited state: H_3(x) = 8x³ - 12x
                let ax = alpha * x
                value *= 8.0 * ax * ax * ax - 12.0 * ax
            default:
                // Higher states - use recursive approach or simplify
                if energyLevel > 4 {
                    // Approximate with a simplified wave function for higher states
                    let classicalAmplitude = sqrt(2 * energy / springConstant)
                    let k = Double.pi * Double(energyLevel) / classicalAmplitude
                    value = gaussianFactor * sin(k * x)
                }
            }

            // Apply normalization factor
            let normalization =
                pow(alpha / Double.pi, 0.25)
                / sqrt(pow(2.0, Double(energyLevel - 1)) * factorial(energyLevel - 1))
            value *= normalization

            // Add time dependence
            let real = value * cos(-timeFactor)
            let imaginary = value * sin(-timeFactor)

            cachedWaveFunction[i] = Complex(real: real, imaginary: imaginary)
        }
    }

    private func calculateHydrogenAtomWaveFunction() {
        // For simplicity, we'll implement only the radial part of hydrogen atom wavefunctions
        // This is a simplified model for visualization purposes

        // Get principal quantum number
        let n = energyLevel

        // For visualization in 1D, we'll use only the radial part R(r)
        for i in 0..<spatialGrid.count {
            let r = max(1e-12, spatialGrid[i])  // Avoid division by zero at r=0

            // Calculate radial wavefunction (simplified for n=1,2,3)
            var radialPart = 0.0

            switch n {
            case 1:
                // 1s orbital: R_10(r) = 2(1/a₀)^(3/2) * exp(-r/a₀)
                radialPart = 2.0 * pow(1.0 / bohrRadius, 1.5) * exp(-r / bohrRadius)
            case 2:
                // 2s orbital: R_20(r) = (1/√2)(1/a₀)^(3/2) * (2 - r/a₀) * exp(-r/2a₀)
                radialPart =
                    (1.0 / sqrt(2.0)) * pow(1.0 / bohrRadius, 1.5) * (2.0 - r / bohrRadius)
                    * exp(-r / (2.0 * bohrRadius))
            case 3:
                // 3s orbital: R_30(r) = (2/√3)(1/a₀)^(3/2) * (1 - 2r/3a₀ + 2r²/27a₀²) * exp(-r/3a₀)
                let rho = r / bohrRadius
                radialPart =
                    (2.0 / sqrt(3.0)) * pow(1.0 / bohrRadius, 1.5)
                    * (1.0 - 2.0 * rho / 3.0 + 2.0 * rho * rho / (27.0)) * exp(-rho / 3.0)
            default:
                // For higher levels, use a simplified approximation
                let effectiveBohrRadius = bohrRadius * Double(n * n)
                radialPart =
                    sqrt(2.0 / (effectiveBohrRadius * effectiveBohrRadius * effectiveBohrRadius))
                    * exp(-r / (effectiveBohrRadius))
                // Add oscillatory behavior similar to higher states
                radialPart *= sin(Double.pi * Double(n) * r / (10.0 * bohrRadius))
            }

            // Normalize for visualization (approximate)
            radialPart *= 1.0 / sqrt(4.0 * Double.pi)

            // Add time dependence
            let energy = getExpectedEnergy()
            let omega = abs(energy) / hBar  // Use magnitude of energy
            let timeFactor = omega * time

            let real = radialPart * cos(-timeFactor)
            let imaginary = radialPart * sin(-timeFactor)

            cachedWaveFunction[i] = Complex(real: real, imaginary: imaginary)
        }
    }

    private func factorial(_ n: Int) -> Double {
        if n <= 1 {
            return 1.0
        }
        var result = 1.0
        for i in 2...n {
            result *= Double(i)
        }
        return result
    }

    // MARK: - Interface Compatibility Methods

    /// Enable or disable time evolution animation
    func setAnimateTimeEvolution(_ animate: Bool) {
        isAnimating = animate
    }

    /// Run the quantum simulation
    func runSimulation() {
        // Only recalculate if parameters have changed or we're past the cache threshold
        if isDirty || currentTime > lastCalculationTime + 0.1 {
            // Store the result or use _ to explicitly ignore it
            _ = calculateWaveFunction(at: currentTime)
            calculateProbabilityDensity()

            // Mark as clean and update timestamp
            isDirty = false
            lastCalculationTime = currentTime
        }
    }

    /// Advance the simulation time
    func advanceTime() {
        if isAnimating {
            currentTime += timeStepSize
            // Trigger recalculation at next opportunity
            isDirty = true
        }
    }

    /// Get real and imaginary components of the wave function
    func getWaveFunctionComponents() -> (real: [Double], imaginary: [Double]) {
        // Reuse the existing optimized calculation method
        return calculateWaveFunction(at: currentTime)
    }

    /// Get the phase of the wave function across the grid
    func getPhaseGrid() -> [Double] {
        // Check cache first
        if let cached = phaseCache[currentTime] {
            return cached
        }

        // Recalculate and cache
        let (real, imaginary) = getWaveFunctionComponents()
        var phases: [Double] = []

        // Calculate phase at each point
        for i in 0..<min(real.count, imaginary.count) {
            phases.append(atan2(imaginary[i], real[i]))
        }

        phaseCache[currentTime] = phases
        return phases
    }

    // MARK: - Cache Management

    /// Clear all caches when parameters change
    private func invalidateCache() {
        isDirty = true
        waveFunctionCache.removeAll()
        phaseCache.removeAll()
        probabilityCache.removeAll()
        cacheTimes.removeAll()
        wavelengthCache = nil
    }

    /// Add a time point to cache with LRU eviction
    private func cacheTimePoint(_ time: Double) {
        // Only track time points we haven't seen
        if !cacheTimes.contains(time) {
            // Add the new time point
            cacheTimes.append(time)

            // If we're over the cache limit, remove oldest entries
            if cacheTimes.count > maxCacheSize {
                // Find oldest time points to remove
                let sortedTimes = cacheTimes.sorted()
                let timesToRemove = sortedTimes.prefix(cacheTimes.count - maxCacheSize)

                // Remove from all caches
                for oldTime in timesToRemove {
                    waveFunctionCache.removeValue(forKey: oldTime)
                    phaseCache.removeValue(forKey: oldTime)
                    probabilityCache.removeValue(forKey: oldTime)
                }

                // Update tracking array
                cacheTimes = Array(sortedTimes.suffix(maxCacheSize))
            }
        }
    }
}
