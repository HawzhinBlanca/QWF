
//
//  QuantumCalculationTests 2.swift
//  QwantumWaveform
//
//  Created by HAWZHIN on 14/03/2025.
//


import XCTest
@testable import QuantumWaveform

final class QuantumCalculationTests: XCTestCase {
    // Test constants
    private let electronMass = 9.1093837e-31 // kg
    private let reducedPlanckConstant = 1.054571817e-34 // ħ in J·s
    private let electronVolt = 1.602176634e-19 // eV in J
    private let bohrRadius = 5.29177210903e-11 // m
    
    // Test instance
    private var simulator: QuantumSimulator!
    
    override func setUp() {
        super.setUp()
        simulator = QuantumSimulator()
    }
    
    override func tearDown() {
        simulator = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testDeBroglieWavelength() {
        // Set up a free particle with known parameters
        simulator.setSystemType(.freeParticle)
        simulator.setParticleMass(electronMass)
        
        // Get the calculated wavelength
        let wavelength = simulator.calculateDeBroglieWavelength()
        
        // Verify it's a reasonable value (non-zero, finite)
        XCTAssertGreaterThan(wavelength, 0, "De Broglie wavelength should be positive")
        XCTAssertTrue(wavelength.isFinite, "De Broglie wavelength should be finite")
        
        // Test with a higher energy level (wavelength should decrease)
        simulator.setEnergyLevel(2)
        let wavelength2 = simulator.calculateDeBroglieWavelength()
        
        // Higher energy means shorter wavelength
        XCTAssertLessThan(wavelength2, wavelength, "Higher energy should have shorter wavelength")
    }
    
    func testPotentialWellEnergy() {
        // Set up infinite potential well
        simulator.setSystemType(.potentialWell)
        simulator.setParticleMass(electronMass)
        
        // Test energy level 1
        simulator.setEnergyLevel(1)
        let energy1 = simulator.getExpectedEnergy()
        
        // Test energy level 2
        simulator.setEnergyLevel(2)
        let energy2 = simulator.getExpectedEnergy()
        
        // Energy should scale as n²
        let expectedRatio = 4.0 // (2/1)²
        XCTAssertEqual(energy2 / energy1, expectedRatio, accuracy: 0.001, "Energy should scale as n²")
    }
    
    func testHarmonicOscillatorEnergy() {
        // Set up harmonic oscillator
        simulator.setSystemType(.harmonicOscillator)
        simulator.setParticleMass(electronMass)
        
        // Test energy level 1
        simulator.setEnergyLevel(1)
        let energy1 = simulator.getExpectedEnergy()
        
        // Test energy level 2
        simulator.setEnergyLevel(2)
        let energy2 = simulator.getExpectedEnergy()
        
        // Energy should scale linearly (n+1/2)*ħω
        let energyDifference = energy2 - energy1
        
        // Calculate the expected difference (ħω)
        let estimatedOmega = energyDifference / reducedPlanckConstant
        
        // Verify the frequency is reasonable (should be around 10¹³ Hz for visualization)
        XCTAssertGreaterThan(estimatedOmega, 1e12, "Angular frequency should be large")
        XCTAssertLessThan(estimatedOmega, 1e15, "Angular frequency should be reasonable")
    }
    
    func testHydrogenAtomEnergy() {
        // Set up hydrogen atom
        simulator.setSystemType(.hydrogenAtom)
        simulator.setParticleMass(electronMass)
        
        // Test energy level 1
        simulator.setEnergyLevel(1)
        let energy1 = simulator.getExpectedEnergy()
        
        // Test energy level 2
        simulator.setEnergyLevel(2)
        let energy2 = simulator.getExpectedEnergy()
        
        // Energy should scale as -1/n²
        // E₂/E₁ = (1/2²)/(1/1²) = 1/4
        let expectedRatio = 0.25 // (1/2)²
        XCTAssertEqual(energy2 / energy1, expectedRatio, accuracy: 0.001, "Energy should scale as -1/n²")
        
        // Energy should be negative for bound states
        XCTAssertLessThan(energy1, 0, "Ground state energy should be negative")
    }
    
    func testProbabilityNormalization() {
        // Test all system types
        let systemTypes: [QuantumSystemType] = [.freeParticle, .potentialWell, .harmonicOscillator, .hydrogenAtom]
        
        for systemType in systemTypes {
            simulator.setSystemType(systemType)
            
            // Get probability density across grid
            let probabilities = simulator.getProbabilityDensityGrid()
            
            // Calculate total probability (approximate integral)
            let probSum = probabilities.reduce(0, +)
            let totalProb = probSum / Double(probabilities.count)
            
            // Should be normalized (approximately 1)
            XCTAssertEqual(totalProb, 1.0, accuracy: 0.1, "Probability should be normalized for \(systemType)")
        }
    }
    
    func testTimeEvolution() {
        // Set free particle for simplicity
        simulator.setSystemType(.freeParticle)
        simulator.setParticleMass(electronMass)
        
        // Get initial state at t=0
        simulator.setTime(0.0)
        let initialProb = simulator.getProbabilityDensityGrid()
        
        // Get state at later time
        simulator.setTime(1.0e-15) // 1 femtosecond
        let laterProb = simulator.getProbabilityDensityGrid()
        
        // States should be different (wave packet should move)
        var difference = false
        for i in 0..<min(initialProb.count, laterProb.count) {
            if abs(initialProb[i] - laterProb[i]) > 1e-6 {
                difference = true
                break
            }
        }
        
        XCTAssertTrue(difference, "Wave function should evolve over time")
        
        // But total probability should remain the same
        let initialTotal = initialProb.reduce(0, +)
        let laterTotal = laterProb.reduce(0, +)
        
        XCTAssertEqual(initialTotal, laterTotal, accuracy: 0.01, "Probability should be conserved over time")
    }
    
    func testPotentialBarrier() {
        // Set free particle
        simulator.setSystemType(.freeParticle)
        simulator.setParticleMass(electronMass)
        
        // Get probability without barrier
        simulator.setPotentialHeight(0.0)
        let probWithoutBarrier = simulator.getProbabilityDensityGrid()
        
        // Get probability with barrier
        simulator.setPotentialHeight(5.0) // 5 eV
        let probWithBarrier = simulator.getProbabilityDensityGrid()
        
        // Should be different
        var difference = false
        for i in 0..<min(probWithoutBarrier.count, probWithBarrier.count) {
            if abs(probWithoutBarrier[i] - probWithBarrier[i]) > 1e-6 {
                difference = true
                break
            }
        }
        
        XCTAssertTrue(difference, "Potential barrier should affect wave function")
    }
    
    static var allTests = [
        ("testDeBroglieWavelength", testDeBroglieWavelength),
        ("testPotentialWellEnergy", testPotentialWellEnergy),
        ("testHarmonicOscillatorEnergy", testHarmonicOscillatorEnergy),
        ("testHydrogenAtomEnergy", testHydrogenAtomEnergy),
        ("testProbabilityNormalization", testProbabilityNormalization),
        ("testTimeEvolution", testTimeEvolution),
        ("testPotentialBarrier", testPotentialBarrier)
    ]
}
