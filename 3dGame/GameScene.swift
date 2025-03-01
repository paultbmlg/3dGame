//
//  GameScene.swift
//  3dGame
//
//  Created by Paul Auer on 23.01.25.
//

import SceneKit

enum MovementDirection {
    case forward
    case backward
    case left
    case right
}

class GameScene: SCNScene {
    
    private var playerNode: SCNNode!
    private var cameraNode: SCNNode!
    private var cameraBase: SCNNode!
    private let moveDistance: Float = 0.1
    
    // Camera follow parameters
    private let cameraHeight: Float = 5
    private let cameraDistance: Float = 10
    private let cameraPitch: Float = -Float.pi / 6
    
    // Add to GameScene class properties
    private let rotationSpeed: Float = 0.5
    
    // Add these properties
    private let jumpHeight: Float = 2.0
    private let jumpDuration: TimeInterval = 0.5
    private var isJumping = false
    
    // Fix fog properties - use proper types and don't override SCNScene properties
    private var myFogStartDistance: CGFloat = 15
    private var myFogEndDistance: CGFloat = 30
    private var myFogColor: UIColor = UIColor(white: 0.9, alpha: 1.0)
    
    override init() {
        super.init()
        setupScene()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupScene()
    }
    
    private func setupScene() {
        // Add skybox for a more immersive environment
        let skyboxImages = [
            UIImage(named: "skybox_right"),
            UIImage(named: "skybox_left"),
            UIImage(named: "skybox_up"),
            UIImage(named: "skybox_down"),
            UIImage(named: "skybox_front"),
            UIImage(named: "skybox_back")
        ]
        
        // Fallback to a gradient if skybox images aren't available
        if skyboxImages.contains(where: { $0 == nil }) {
            let gradientStart = UIColor(red: 0.1, green: 0.2, blue: 0.4, alpha: 1.0)
            let gradientEnd = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
            background.contents = [gradientStart, gradientEnd]
        } else {
            background.contents = skyboxImages
        }
        
        // Add fog for depth perception - use scene's fog properties
        fogStartDistance = myFogStartDistance
        fogEndDistance = myFogEndDistance
        fogColor = myFogColor
        
        createGround()
        createPlayer()
        createReferenceObject()
        createDecorations() // Add environmental objects
        createCamera()
        
        // Add particle system for ambient atmosphere
        addAmbientParticles()
    }
    
    private func createCamera() {
        // Create camera base node
        cameraBase = SCNNode()
        rootNode.addChildNode(cameraBase)
        
        // Create camera node
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        // Set up camera position and orientation
        cameraNode.position = SCNVector3(0, cameraHeight, cameraDistance)
        cameraNode.eulerAngles.x = cameraPitch
        
        // Add camera to base
        cameraBase.addChildNode(cameraNode)
        
        // Ensure initial position is set
        updateCameraPosition()
    }
    
    private func createGround() {
        let groundGeometry = SCNFloor()
        
        // Create a more interesting ground texture
        let size = 1024 // Larger texture for more detail
        let squareSize = 64
        
        UIGraphicsBeginImageContext(CGSize(width: size, height: size))
        guard let context = UIGraphicsGetCurrentContext() else {
            // Return a default image if context creation fails
            return
        }
        
        // Draw base color
        let baseColor = UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        context.setFillColor(baseColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        
        // Draw grid lines
        context.setStrokeColor(UIColor(white: 0.9, alpha: 0.7).cgColor)
        context.setLineWidth(2.0)
        
        // Draw horizontal lines
        for row in 0...size/squareSize {
            let y = CGFloat(row * squareSize)
            context.move(to: CGPoint(x: CGFloat(0), y: y))
            context.addLine(to: CGPoint(x: CGFloat(size), y: y))
        }
        
        // Draw vertical lines
        for col in 0...size/squareSize {
            let x = CGFloat(col * squareSize)
            context.move(to: CGPoint(x: x, y: CGFloat(0)))
            context.addLine(to: CGPoint(x: x, y: CGFloat(size)))
        }
        
        context.strokePath()
        
        let groundTexture = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Create materials with PBR properties
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = groundTexture
        groundMaterial.diffuse.wrapS = .repeat
        groundMaterial.diffuse.wrapT = .repeat
        groundMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(20), Float(20), Float(1))
        
        // Add normal mapping for texture depth
        groundMaterial.normal.contents = generateNoiseTexture(size: 256, scale: 0.5)
        groundMaterial.normal.intensity = CGFloat(Float(0.5))
        
        // Physical properties
        groundMaterial.roughness.contents = CGFloat(0.8)
        groundMaterial.metalness.contents = CGFloat(0.0)
        
        groundGeometry.materials = [groundMaterial]
        
        let groundNode = SCNNode(geometry: groundGeometry)
        groundNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        rootNode.addChildNode(groundNode)
    }
    
    private func createPlayer() {
        // Create a more interesting player model
        let playerGeometry = SCNCapsule(capRadius: 0.5, height: 1.5)
        playerNode = SCNNode(geometry: playerGeometry)
        playerNode.position = SCNVector3(0, 1.0, 0) // Higher position for capsule
        
        // Create metallic blue material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1.0)
        material.specular.contents = UIColor.white
        material.metalness.contents = 0.7
        material.roughness.contents = 0.3
        playerGeometry.materials = [material]
        
        // Add direction indicator
        let frontGeometry = SCNCone(topRadius: 0, bottomRadius: 0.3, height: 0.6)
        let frontNode = SCNNode(geometry: frontGeometry)
        frontNode.position = SCNVector3(0, 0, -0.8)
        frontNode.eulerAngles.x = Float.pi / 2 // Rotate to point forward
        
        let frontMaterial = SCNMaterial()
        frontMaterial.diffuse.contents = UIColor.red
        frontMaterial.emission.contents = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.5)
        frontGeometry.materials = [frontMaterial]
        
        playerNode.addChildNode(frontNode)
        
        // Add subtle glow effect
        let glowNode = SCNNode()
        glowNode.light = SCNLight()
        glowNode.light?.type = .omni
        glowNode.light?.color = UIColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1.0)
        glowNode.light?.intensity = 100
        glowNode.light?.attenuationStartDistance = 0.5
        glowNode.light?.attenuationEndDistance = 1.5
        playerNode.addChildNode(glowNode)
        
        rootNode.addChildNode(playerNode)
    }
    
    private func createReferenceObject() {
        // Create multiple reference objects for better spatial awareness
        createPyramid(position: SCNVector3(5, 0, 0), color: .green)
        createPyramid(position: SCNVector3(-5, 0, 5), color: .orange)
        createPyramid(position: SCNVector3(0, 0, -7), color: .purple)
        createPyramid(position: SCNVector3(-3, 0, -3), color: .yellow)
    }
    
    private func createPyramid(position: SCNVector3, color: UIColor) {
        // Fix initializer error by providing explicit CGFloat values
        let pyramidGeometry = SCNPyramid(width: CGFloat(1.0), height: CGFloat(2.0), length: CGFloat(1.0))
        let pyramidNode = SCNNode(geometry: pyramidGeometry)
        pyramidNode.position = position
        
        // Create material with emission for glow effect
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color.withAlphaComponent(0.3)
        // Convert Float to CGFloat for material properties
        material.metalness.contents = CGFloat(0.5)
        material.roughness.contents = CGFloat(0.5)
        pyramidGeometry.materials = [material]
        
        // Add subtle animation
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat(Float.pi * 2), z: 0, duration: 20)
        let repeatAction = SCNAction.repeatForever(rotateAction)
        pyramidNode.runAction(repeatAction)
        
        rootNode.addChildNode(pyramidNode)
    }
    
    private func createDecorations() {
        // Add some trees or pillars for visual interest
        for _ in 0..<15 {
            let x = Float.random(in: -20...20)
            let z = Float.random(in: -20...20)
            
            // Don't place too close to player start position
            if abs(x) < 3 && abs(z) < 3 { continue }
            
            createTree(position: SCNVector3(x, 0, z))
        }
        
        // Add some rocks
        for _ in 0..<20 {
            let x = Float.random(in: -25...25)
            let z = Float.random(in: -25...25)
            
            // Don't place too close to player start position
            if abs(x) < 4 && abs(z) < 4 { continue }
            
            createRock(position: SCNVector3(x, 0, z))
        }
    }
    
    private func createTree(position: SCNVector3) {
        // Create trunk
        let trunkGeometry = SCNCylinder(radius: 0.3, height: 3.0)
        let trunkMaterial = SCNMaterial()
        trunkMaterial.diffuse.contents = UIColor.brown
        trunkMaterial.roughness.contents = 0.9
        trunkGeometry.materials = [trunkMaterial]
        
        let trunkNode = SCNNode(geometry: trunkGeometry)
        trunkNode.position = SCNVector3(position.x, 1.5, position.z)
        
        // Create foliage
        let foliageGeometry = SCNCone(topRadius: 0, bottomRadius: 1.5, height: 3.0)
        let foliageMaterial = SCNMaterial()
        foliageMaterial.diffuse.contents = UIColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0)
        foliageMaterial.roughness.contents = 0.8
        foliageGeometry.materials = [foliageMaterial]
        
        let foliageNode = SCNNode(geometry: foliageGeometry)
        foliageNode.position = SCNVector3(0, 2.5, 0)
        
        trunkNode.addChildNode(foliageNode)
        rootNode.addChildNode(trunkNode)
    }
    
    private func createRock(position: SCNVector3) {
        // Fix Float to CGFloat conversion
        let rockGeometry = SCNSphere(radius: CGFloat(0.5 * Float.random(in: 0.5...1.5)))
        
        // Deform the sphere to look more like a rock - fix tessellation
        rockGeometry.segmentCount = 8 // Use segmentCount instead of tessellator
        
        let rockMaterial = SCNMaterial()
        rockMaterial.diffuse.contents = UIColor(white: CGFloat(Float.random(in: 0.4...0.7)), alpha: 1.0)
        // Convert Float to CGFloat for material property
        rockMaterial.roughness.contents = CGFloat(1.0)
        rockGeometry.materials = [rockMaterial]
        
        let rockNode = SCNNode(geometry: rockGeometry)
        // Fix CGFloat to Float conversion by converting radius back to Float
        rockNode.position = SCNVector3(position.x, Float(rockGeometry.radius) * 0.8, position.z)
        
        // Random rotation for variety
        rockNode.eulerAngles = SCNVector3(
            Float.random(in: 0...Float.pi),
            Float.random(in: 0...Float.pi),
            Float.random(in: 0...Float.pi)
        )
        
        rootNode.addChildNode(rockNode)
    }
    
    private func addAmbientParticles() {
        // Create a particle system for ambient atmosphere
        let particleSystem = SCNParticleSystem()
        particleSystem.birthRate = 10
        particleSystem.particleLifeSpan = 10
        particleSystem.emitterShape = SCNSphere(radius: 20)
        particleSystem.particleColor = UIColor(white: 1.0, alpha: 0.3)
        particleSystem.particleSize = 0.1
        particleSystem.speedFactor = 0.2
        particleSystem.isAffectedByGravity = false
        particleSystem.isAffectedByPhysicsFields = true
        
        let particleNode = SCNNode()
        particleNode.addParticleSystem(particleSystem)
        rootNode.addChildNode(particleNode)
        
        // Add a gentle wind field - fix physics field type
        let windField = SCNPhysicsField.vortex() // Use vortex instead of vortexField
        windField.strength = 0.5
        windField.falloffExponent = 0.5
        
        let windNode = SCNNode()
        windNode.physicsField = windField
        windNode.position = SCNVector3(10, 5, 10)
        rootNode.addChildNode(windNode)
    }
    
    // Helper function to generate a noise texture for normal mapping
    private func generateNoiseTexture(size: Int, scale: CGFloat) -> UIImage {
        let width = size
        let height = size
        
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        guard let context = UIGraphicsGetCurrentContext() else {
            // Return a default image if context creation fails
            return UIImage()
        }
        
        for y in 0..<height {
            for x in 0..<width {
                let noise = CGFloat(arc4random_uniform(100)) / 100.0 * scale
                let color = UIColor(white: 0.5 + noise, alpha: 1.0)
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(1), height: CGFloat(1)))
            }
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func updateCameraPosition() {
        guard let playerPosition = playerNode?.position else { return }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0/60.0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .linear)
        cameraBase.position = playerPosition
        SCNTransaction.commit()
    }
    
    func updatePlayerRotation() {
        let cameraDirection = cameraNode.presentation.worldPosition - playerNode.presentation.worldPosition
        let angle = atan2(cameraDirection.x, cameraDirection.z)
        playerNode.eulerAngles.y = angle
    }
    
    func movePlayer(direction: MovementDirection) {
        let cameraForward = cameraNode.presentation.worldPosition - playerNode.presentation.worldPosition
        let cameraRotation = atan2(cameraForward.x, cameraForward.z)
        
        var moveVector = SCNVector3Zero
        switch direction {
        case .forward:
            moveVector = SCNVector3(-sin(cameraRotation), 0, -cos(cameraRotation))
        case .backward:
            moveVector = SCNVector3(sin(cameraRotation), 0, cos(cameraRotation))
        case .left:
            moveVector = SCNVector3(-cos(cameraRotation), 0, sin(cameraRotation))
        case .right:
            moveVector = SCNVector3(cos(cameraRotation), 0, -sin(cameraRotation))
        }
        
        moveVector = moveVector * moveDistance
        
        // Add smooth animation
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0/60.0 // Match the timer interval
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .linear)
        playerNode.position += moveVector
        SCNTransaction.commit()
    }
    
    // Update the rotateCamera function
    func rotateCamera(delta: CGPoint) {
        // Apply horizontal rotation to the camera base
        let horizontalRotation = Float(delta.x)  // Convert CGFloat to Float
        cameraBase.eulerAngles.y -= horizontalRotation
        
        // Apply vertical rotation to the camera with limits
        let verticalRotation = Float(delta.y)    // Convert CGFloat to Float
        let newPitch = cameraNode.eulerAngles.x - verticalRotation
        
        // Limit vertical rotation between -60 and 45 degrees
        let minPitch: Float = -Float.pi / 3  // -60 degrees
        let maxPitch: Float = Float.pi / 4   // 45 degrees
        cameraNode.eulerAngles.x = min(max(newPitch, minPitch), maxPitch)
        
        // Force update camera position
        updateCameraPosition()
    }
    
    // Enhance jump with visual effects
    func jump() {
        if isJumping { return }
        
        isJumping = true
        
        // Create particle effect for jump
        let jumpParticles = SCNParticleSystem()
        jumpParticles.birthRate = 500
        jumpParticles.particleLifeSpan = 0.5
        jumpParticles.emissionDuration = 0.1
        jumpParticles.spreadingAngle = 45
        jumpParticles.particleColor = UIColor.white
        jumpParticles.particleColorVariation = SCNVector4(0.1, 0.1, 0.1, 0)
        jumpParticles.particleSize = 0.05
        jumpParticles.isAffectedByGravity = true
        jumpParticles.acceleration = SCNVector3(0, -5, 0)
        
        // Add particles at jump start
        playerNode.addParticleSystem(jumpParticles)
        
        // Jump animation
        let jumpUp = SCNAction.moveBy(x: 0, y: CGFloat(jumpHeight), z: 0, duration: jumpDuration/2)
        jumpUp.timingMode = .easeOut
        
        let jumpDown = SCNAction.moveBy(x: 0, y: CGFloat(-jumpHeight), z: 0, duration: jumpDuration/2)
        jumpDown.timingMode = .easeIn
        
        let sequence = SCNAction.sequence([jumpUp, jumpDown])
        
        // Add landing particles
        let landAction = SCNAction.run { [weak self] node in
            guard let self = self else { return }
            
            // Create landing effect
            let landParticles = SCNParticleSystem()
            landParticles.birthRate = 800
            landParticles.particleLifeSpan = 0.7
            landParticles.emissionDuration = 0.1
            landParticles.spreadingAngle = 90
            landParticles.particleColor = UIColor.white
            landParticles.particleSize = 0.05
            landParticles.isAffectedByGravity = true
            
            self.playerNode.addParticleSystem(landParticles)
        }
        
        // Add cleanup action to remove particle systems
        let cleanupAction = SCNAction.run { [weak self] node in
            // Wait a bit before removing particles to let them finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.playerNode.removeAllParticleSystems()
            }
        }
        
        let completeSequence = SCNAction.sequence([sequence, landAction, cleanupAction])
        
        playerNode.runAction(completeSequence) { [weak self] in
            self?.isJumping = false
        }
    }
}

// Helper extension to generate random colors
extension UIColor {
    static var random: UIColor {
        return UIColor(red: .random(in: 0...1),
                      green: .random(in: 0...1),
                      blue: .random(in: 0...1),
                      alpha: 1.0)
    }
}

// Add this extension to help with rotation calculations
extension SCNMatrix4 {
    var rotationY: Float {
        return -atan2f(m31, m33)
    }
}

extension SCNVector3 {
    static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        return SCNVector3(l.x - r.x, l.y - r.y, l.z - r.z)
    }
    
    static func * (v: SCNVector3, s: Float) -> SCNVector3 {
        return SCNVector3(v.x * s, v.y * s, v.z * s)
    }
    
    static func += (l: inout SCNVector3, r: SCNVector3) {
        l = SCNVector3(l.x + r.x, l.y + r.y, l.z + r.z)
    }
}
