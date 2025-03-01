//
//  GameViewController.swift
//  3dGame
//
//  Created by Paul Auer on 23.01.25.
//

import UIKit
import SceneKit

class GameViewController: UIViewController {
    
    var sceneView: SCNView!
    var scene: GameScene!
    
    private var lastPanLocation: CGPoint?
    private var panning = false
    private var moveTimer: Timer?
    private var currentDirection: MovementDirection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a new SceneKit view
        sceneView = view as? SCNView
        if sceneView == nil {
            sceneView = SCNView(frame: view.frame)
            view = sceneView
        }
        
        // Create a new scene
        scene = GameScene()
        
        // Create and add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLight)
        
        // Create and add omnidirectional light
        let omniLight = SCNNode()
        omniLight.light = SCNLight()
        omniLight.light?.type = .omni
        omniLight.position = SCNVector3(10, 10, 10)
        scene.rootNode.addChildNode(omniLight)
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Configure the view
        sceneView.backgroundColor = UIColor.black
        sceneView.autoenablesDefaultLighting = true
        sceneView.showsStatistics = true
        
        // Add control buttons
        setupControlButtons()
        
        // Configure camera controls
        sceneView.allowsCameraControl = false
        
        // Add pan gesture recognizer for camera rotation
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panRecognizer.maximumNumberOfTouches = 1
        sceneView.addGestureRecognizer(panRecognizer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Add camera rotation observer
        sceneView.scene?.isPaused = false
        sceneView.preferredFramesPerSecond = 60
        
        // Add a render loop to continuously update player rotation
        sceneView.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Clean up
        stopMovement()
        sceneView.delegate = nil
        sceneView.scene = nil
    }
    
    deinit {
        stopMovement()
        sceneView.delegate = nil
        sceneView.scene = nil
    }
    
    private func setupControlButtons() {
        // Create a visually appealing control pad with better layout
        let buttonSize: CGFloat = 60
        let spacing: CGFloat = 8
        let bottomPadding: CGFloat = 50
        
        // Center point for the directional pad
        let centerX = view.bounds.width * 0.25
        let centerY = view.bounds.height - (2 * buttonSize + spacing + bottomPadding)
        
        // Up button
        let upButton = createButton(title: "↑", action: #selector(moveUp))
        upButton.frame = CGRect(
            x: centerX - buttonSize/2,
            y: centerY - buttonSize - spacing,
            width: buttonSize, 
            height: buttonSize
        )
        
        // Left button
        let leftButton = createButton(title: "←", action: #selector(moveLeft))
        leftButton.frame = CGRect(
            x: centerX - buttonSize - spacing,
            y: centerY,
            width: buttonSize, 
            height: buttonSize
        )
        
        // Right button
        let rightButton = createButton(title: "→", action: #selector(moveRight))
        rightButton.frame = CGRect(
            x: centerX + spacing,
            y: centerY,
            width: buttonSize, 
            height: buttonSize
        )
        
        // Down button
        let downButton = createButton(title: "↓", action: #selector(moveDown))
        downButton.frame = CGRect(
            x: centerX - buttonSize/2,
            y: centerY + buttonSize + spacing,
            width: buttonSize, 
            height: buttonSize
        )
        
        // Add jump button on the right side
        let jumpButton = createJumpButton()
        jumpButton.frame = CGRect(
            x: view.bounds.width * 0.75 - buttonSize/2,
            y: view.bounds.height - buttonSize - bottomPadding,
            width: buttonSize * 1.5,
            height: buttonSize
        )
        
        view.addSubview(jumpButton)
        view.addSubview(upButton)
        view.addSubview(downButton)
        view.addSubview(leftButton)
        view.addSubview(rightButton)
    }
    
    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        
        // Improved styling for buttons
        button.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.7)
        button.layer.cornerRadius = 30
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        // Add shadow for depth
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 5
        button.layer.shadowOpacity = 0.5
        
        // Add touch down and touch up handlers
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        // Store the movement direction in the button's tag
        switch action {
        case #selector(moveUp):
            button.tag = 0 // Forward
        case #selector(moveDown):
            button.tag = 1 // Backward
        case #selector(moveLeft):
            button.tag = 2 // Left
        case #selector(moveRight):
            button.tag = 3 // Right
        default:
            break
        }
        
        return button
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        // Visual feedback when button is pressed
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 1.0
            
            if sender.titleLabel?.text == "JUMP" {
                sender.backgroundColor = UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 0.9)
            } else {
                sender.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.9)
            }
        }
        
        // Stop any existing movement
        stopMovement()
        
        // Set the current direction based on button tag
        currentDirection = {
            switch sender.tag {
            case 0: return .forward
            case 1: return .backward
            case 2: return .left
            case 3: return .right
            default: return nil
            }
        }()
        
        // Move immediately
        if let direction = currentDirection {
            scene.movePlayer(direction: direction)
        }
        
        // Start continuous movement with shorter interval (60fps)
        moveTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            if let direction = self?.currentDirection {
                self?.scene.movePlayer(direction: direction)
            }
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        // Visual feedback when button is released
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.alpha = 1.0
            
            if sender.titleLabel?.text == "JUMP" {
                sender.backgroundColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.7)
            } else {
                sender.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.7)
            }
        }
        
        stopMovement()
    }
    
    private func stopMovement() {
        moveTimer?.invalidate()
        moveTimer = nil
        currentDirection = nil
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: sceneView)
        
        switch gesture.state {
        case .began:
            lastPanLocation = gesture.location(in: sceneView)
            panning = true
        case .changed:
            // Increase rotation speed for more noticeable effect
            let rotationFactor: CGFloat = 0.005
            let deltaX = translation.x * rotationFactor
            let deltaY = translation.y * rotationFactor  // Add vertical rotation
            
            // Apply rotation with both horizontal and vertical components
            scene.rotateCamera(delta: CGPoint(x: deltaX, y: deltaY))
            
            // Reset translation to avoid accumulation
            gesture.setTranslation(.zero, in: sceneView)
        case .ended, .cancelled:
            panning = false
            lastPanLocation = nil
        default:
            break
        }
    }
    
    @objc private func moveUp() {
        // This method needs to exist for the selector, but won't be called directly
    }
    
    @objc private func moveDown() {
        // This method needs to exist for the selector, but won't be called directly
    }
    
    @objc private func moveLeft() {
        // This method needs to exist for the selector, but won't be called directly
    }
    
    @objc private func moveRight() {
        // This method needs to exist for the selector, but won't be called directly
    }
    
    private func createJumpButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("JUMP", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        
        // Distinctive styling for jump button
        button.backgroundColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.7)
        button.layer.cornerRadius = 30
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        
        // Add shadow for depth
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 5
        button.layer.shadowOpacity = 0.5
        
        // Add glow effect when pressed
        button.addTarget(self, action: #selector(jumpButtonPressed), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpOutside, .touchCancel])
        
        return button
    }
    
    @objc private func jumpButtonPressed() {
        scene.jump()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

extension GameViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        scene.updatePlayerRotation()
        scene.updateCameraPosition()
    }
}
