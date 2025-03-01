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
    
    override init() {
        super.init()
        setupScene()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupScene()
    }
    
    private func setupScene() {
        background.contents = UIColor.black
        
        // Create ground
        createGround()
        
        // Create player cube
        createPlayer()
        
        // Create reference object
        createReferenceObject()
        
        // Create and setup camera
        createCamera()
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
        
        // Create a checkerboard pattern
        let size = 512 // Size of the texture
        let squareSize = 64 // Size of each checker square
        
        UIGraphicsBeginImageContext(CGSize(width: size, height: size))
        if let context = UIGraphicsGetCurrentContext() {
            // Draw white background
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            
            // Draw black squares
            context.setFillColor(UIColor.black.cgColor)
            
            for row in 0...(size/squareSize) {
                for col in 0...(size/squareSize) {
                    if (row + col) % 2 == 0 {
                        context.fill(CGRect(x: col * squareSize, 
                                          y: row * squareSize, 
                                          width: squareSize, 
                                          height: squareSize))
                    }
                }
            }
        }
        
        let checkerboardImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Create material with the checkerboard pattern
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = checkerboardImage
        groundMaterial.diffuse.wrapS = .repeat
        groundMaterial.diffuse.wrapT = .repeat
        
        // Scale the texture
        groundMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(10, 10, 1)
        
        // Make it less shiny
        groundMaterial.roughness.contents = 1.0
        
        groundGeometry.materials = [groundMaterial]
        
        let groundNode = SCNNode(geometry: groundGeometry)
        groundNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        rootNode.addChildNode(groundNode)
    }
    
    private func createPlayer() {
        // Create main cube
        let boxGeometry = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.1)
        playerNode = SCNNode(geometry: boxGeometry)
        playerNode.position = SCNVector3(0, 0.5, 0)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue
        boxGeometry.materials = [material]
        
        // Add direction indicator (red part)
        let frontGeometry = SCNBox(width: 0.3, height: 0.3, length: 0.6, chamferRadius: 0)
        let frontNode = SCNNode(geometry: frontGeometry)
        frontNode.position = SCNVector3(0, 0, -0.8)
        
        let frontMaterial = SCNMaterial()
        frontMaterial.diffuse.contents = UIColor.red
        frontGeometry.materials = [frontMaterial]
        
        playerNode.addChildNode(frontNode)
        rootNode.addChildNode(playerNode)
    }
    
    private func createReferenceObject() {
        let pyramidGeometry = SCNPyramid(width: 1.0, height: 2.0, length: 1.0)
        let pyramidNode = SCNNode(geometry: pyramidGeometry)
        pyramidNode.position = SCNVector3(5, 0, 0) // Position 5 units to the right
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.green
        pyramidGeometry.materials = [material]
        
        rootNode.addChildNode(pyramidNode)
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
    
    // Add this method
    func jump() {
        // Don't allow jumping if already in the air
        if isJumping { return }
        
        isJumping = true
        
        // Calculate jump up and down actions
        let jumpUp = SCNAction.moveBy(
            x: 0,
            y: CGFloat(jumpHeight),  // Convert Float to CGFloat
            z: 0,
            duration: jumpDuration/2
        )
        jumpUp.timingMode = SCNActionTimingMode.easeOut
        
        let jumpDown = SCNAction.moveBy(
            x: 0,
            y: CGFloat(-jumpHeight), // Convert Float to CGFloat
            z: 0,
            duration: jumpDuration/2
        )
        jumpDown.timingMode = SCNActionTimingMode.easeIn
        
        // Combine actions
        let jumpSequence = SCNAction.sequence([jumpUp, jumpDown])
        
        // Run jump animation
        playerNode.runAction(jumpSequence) { [weak self] in
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
