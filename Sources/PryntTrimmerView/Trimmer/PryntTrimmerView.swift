//
//  PryntTrimmerView.swift
//  PryntTrimmerView
//
//  Created by HHK on 27/03/2017.
//  Copyright © 2017 Prynt. All rights reserved.
//

import AVFoundation
import UIKit

public protocol TrimmerViewDelegate: AnyObject {
    func didChangePositionBar(_ playerTime: CMTime)
    func positionBarStoppedMoving(_ playerTime: CMTime)
}

/// A view to select a specific time range of a video. It consists of an asset preview with thumbnails inside a scroll view, two
/// handles on the side to select the beginning and the end of the range, and a position bar to synchronize the control with a
/// video preview, typically with an `AVPlayer`.
/// Load the video by setting the `asset` property. Access the `startTime` and `endTime` of the view to get the selected time
// range
@IBDesignable public class TrimmerView: AVAssetTimeSelector {

    // MARK: - Properties

    // MARK: Color Customization

    /// The color of the main border of the view
    @IBInspectable public var mainColor: UIColor = UIColor.orange {
        didSet {
            updateMainColor()
        }
    }

    /// The color of the handles on the side of the view
    @IBInspectable public var handleColor: UIColor = UIColor.gray {
        didSet {
           updateHandleColor()
        }
    }

    /// The color of the position indicator
    @IBInspectable public var positionBarColor: UIColor = UIColor.white {
        didSet {
            positionBar.backgroundColor = positionBarColor
        }
    }

    /// The color used to mask unselected parts of the video
    @IBInspectable public var maskColor: UIColor = UIColor.white {
        didSet {
            leftMaskView.backgroundColor = maskColor
            rightMaskView.backgroundColor = maskColor
        }
    }

    // MARK: Interface

    public weak var delegate: TrimmerViewDelegate?

    // MARK: Subviews

    private let trimView = UIView()
    private let leftHandleView = HandlerView()
    private let rightHandleView = HandlerView()
    private let positionBar = UIView()
    private let leftHandleKnob = UIView()
    private let rightHandleKnob = UIView()
    private let leftMaskView = UIView()
    private let rightMaskView = UIView()
    private var leftHandleOriginalPosition: CGFloat?
    private var rightHandleOriginalPosition: CGFloat?

    // MARK: Constraints

    private var currentLeftConstraint: CGFloat = 0
    private var currentRightConstraint: CGFloat = 0
    private var leftConstraint: NSLayoutConstraint?
    private var rightConstraint: NSLayoutConstraint?
    private var positionConstraint: NSLayoutConstraint?
    private var previousFrameWidth: CGFloat?

    private let handleWidth: CGFloat = 15

    /// The minimum duration allowed for the trimming. The handles won't pan further if the minimum duration is attained.
    public var minDuration: Double = 3

    // MARK: - View & constraints configurations

    override func setupSubviews() {
        super.setupSubviews()
        layer.cornerRadius = 2
        layer.masksToBounds = true
        backgroundColor = UIColor.clear
        layer.zPosition = 1
        setupTrimmerView()
        setupHandleView()
        setupMaskView()
        setupPositionBar()
        setupGestures()
        updateMainColor()
        updateHandleColor()
        previousFrameWidth = frame.width
    }

    override func constrainAssetPreview() {
        assetPreview.leftAnchor.constraint(equalTo: leftAnchor, constant: handleWidth).isActive = true
        assetPreview.rightAnchor.constraint(equalTo: rightAnchor, constant: -handleWidth).isActive = true
        assetPreview.topAnchor.constraint(equalTo: topAnchor).isActive = true
        assetPreview.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }

    private func setupTrimmerView() {
        trimView.layer.borderWidth = 2.0
        trimView.layer.cornerRadius = 2.0
        trimView.translatesAutoresizingMaskIntoConstraints = false
        trimView.isUserInteractionEnabled = false
        addSubview(trimView)

        trimView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        trimView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        leftConstraint = trimView.leftAnchor.constraint(equalTo: leftAnchor)
        rightConstraint = trimView.rightAnchor.constraint(equalTo: rightAnchor)
        leftConstraint?.isActive = true
        rightConstraint?.isActive = true
    }

    private func setupHandleView() {

        leftHandleView.isUserInteractionEnabled = true
        leftHandleView.layer.cornerRadius = 2.0
        leftHandleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftHandleView)

        leftHandleView.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        leftHandleView.widthAnchor.constraint(equalToConstant: handleWidth).isActive = true
        leftHandleView.leftAnchor.constraint(equalTo: trimView.leftAnchor).isActive = true
        leftHandleView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        leftHandleKnob.translatesAutoresizingMaskIntoConstraints = false
        leftHandleView.addSubview(leftHandleKnob)

        leftHandleKnob.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5).isActive = true
        leftHandleKnob.widthAnchor.constraint(equalToConstant: 2).isActive = true
        leftHandleKnob.centerYAnchor.constraint(equalTo: leftHandleView.centerYAnchor).isActive = true
        leftHandleKnob.centerXAnchor.constraint(equalTo: leftHandleView.centerXAnchor).isActive = true

        rightHandleView.isUserInteractionEnabled = true
        rightHandleView.layer.cornerRadius = 2.0
        rightHandleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightHandleView)

        rightHandleView.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        rightHandleView.widthAnchor.constraint(equalToConstant: handleWidth).isActive = true
        rightHandleView.rightAnchor.constraint(equalTo: trimView.rightAnchor).isActive = true
        rightHandleView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        rightHandleKnob.translatesAutoresizingMaskIntoConstraints = false
        rightHandleView.addSubview(rightHandleKnob)

        rightHandleKnob.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5).isActive = true
        rightHandleKnob.widthAnchor.constraint(equalToConstant: 2).isActive = true
        rightHandleKnob.centerYAnchor.constraint(equalTo: rightHandleView.centerYAnchor).isActive = true
        rightHandleKnob.centerXAnchor.constraint(equalTo: rightHandleView.centerXAnchor).isActive = true
    }

    private func setupMaskView() {

        leftMaskView.isUserInteractionEnabled = false
        leftMaskView.backgroundColor = .white
        leftMaskView.alpha = 0.7
        leftMaskView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(leftMaskView, belowSubview: leftHandleView)

        leftMaskView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        leftMaskView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        leftMaskView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        leftMaskView.rightAnchor.constraint(equalTo: leftHandleView.centerXAnchor).isActive = true

        rightMaskView.isUserInteractionEnabled = false
        rightMaskView.backgroundColor = .white
        rightMaskView.alpha = 0.7
        rightMaskView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(rightMaskView, belowSubview: rightHandleView)

        rightMaskView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        rightMaskView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        rightMaskView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        rightMaskView.leftAnchor.constraint(equalTo: rightHandleView.centerXAnchor).isActive = true
    }

    private func setupPositionBar() {

        positionBar.frame = CGRect(x: 0, y: 0, width: 3, height: frame.height)
        positionBar.backgroundColor = positionBarColor
        positionBar.center = CGPoint(x: leftHandleView.frame.maxX, y: center.y)
        positionBar.layer.cornerRadius = 1
        positionBar.translatesAutoresizingMaskIntoConstraints = false
        positionBar.isUserInteractionEnabled = false
        addSubview(positionBar)

        positionBar.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        positionBar.widthAnchor.constraint(equalToConstant: 3).isActive = true
        positionBar.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        positionConstraint = positionBar.leftAnchor.constraint(equalTo: leftHandleView.rightAnchor, constant: 0)
        positionConstraint?.isActive = true
    }

    private func setupGestures() {

        let leftPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TrimmerView.handlePanGesture))
        leftHandleView.addGestureRecognizer(leftPanGestureRecognizer)
        let rightPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TrimmerView.handlePanGesture))
        rightHandleView.addGestureRecognizer(rightPanGestureRecognizer)
    }

    private func updateMainColor() {
        trimView.layer.borderColor = mainColor.cgColor
        leftHandleView.backgroundColor = mainColor
        rightHandleView.backgroundColor = mainColor
    }

    private func updateHandleColor() {
        leftHandleKnob.backgroundColor = handleColor
        rightHandleKnob.backgroundColor = handleColor
    }

    // MARK: - Trim Gestures

    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let view = gestureRecognizer.view, let superView = gestureRecognizer.view?.superview else { return }
        let isLeftGesture = view == leftHandleView
        switch gestureRecognizer.state {

        case .began:
            if isLeftGesture {
                currentLeftConstraint = leftConstraint!.constant
            } else {
                currentRightConstraint = rightConstraint!.constant
            }
            updateSelectedTime(stoppedMoving: false)
        case .changed:
            let translation = gestureRecognizer.translation(in: superView)
            if isLeftGesture {
                updateLeftConstraint(with: translation)
                print(leftConstraint!.constant)
            } else {
                updateRightConstraint(with: translation)
                print(rightConstraint!.constant)
            }
            layoutIfNeeded()
            if let startTime = startTime, isLeftGesture {
                seek(to: startTime)
            } else if let endTime = endTime {
                seek(to: endTime)
            }
            updateSelectedTime(stoppedMoving: false)

        case .cancelled, .ended, .failed:
            updateSelectedTime(stoppedMoving: true)
        default: break
        }
    }

    private func updateLeftConstraint(with translation: CGPoint) {
        let maxConstraint = max(rightHandleView.frame.origin.x - handleWidth - minimumDistanceBetweenHandle, 0)
        let newConstraint = min(max(0, currentLeftConstraint + translation.x), maxConstraint)
        leftConstraint?.constant = newConstraint
        print("leftConstraint?.constant \(leftConstraint!.constant)")
    }

    private func updateRightConstraint(with translation: CGPoint) {
        let maxConstraint = min(2 * handleWidth - frame.width + leftHandleView.frame.origin.x + minimumDistanceBetweenHandle, 0)
        let newConstraint = max(min(0, currentRightConstraint + translation.x), maxConstraint)
        rightConstraint?.constant = newConstraint
        print("rightConstraint?.constant \(rightConstraint!.constant)")
    }
    
        
//    private func updateLeftConstraintForTransition(with translation: CGPoint) {
//
//        rightHandleView.frame.origin.x = ((rightHandleOriginalPosition! + (2 * handleWidth)) / previousFrameWidth!) * frame.width - handleWidth
//        let maxConstraint = max(rightHandleView.frame.origin.x - handleWidth - minimumDistanceBetweenHandle, 0)
//        let newConstraint = min(max(0, currentLeftConstraint * (frame.width / previousFrameWidth!) + translation.x), maxConstraint).rounded(.down)
//
//        leftConstraint?.constant = newConstraint
//        leftHandleView.frame.origin.x = newConstraint
//    }
    
    
//    public func setTrimmerHandleOrigin(startTime start: CMTime, endTime end: CMTime) {
//        leftHandleOriginalPosition = getPosition(from: start)
//        rightHandleOriginalPosition = getPosition(from: end)
//    }
    
    
//    private func updateRightConstraintForTransition(with translation: CGPoint) {
//
//        leftHandleView.frame.origin.x = (leftHandleOriginalPosition! / previousFrameWidth!) * frame.width
//
//        let maxConstraint = CGFloat(floor(Double(( min((2 * handleWidth) + leftHandleView.frame.origin.x + minimumDistanceBetweenHandle - frame.width, 0) ))))
//        let newConstraint = max(min(0, (currentRightConstraint * (previousFrameWidth! / frame.width)) + translation.x), maxConstraint).rounded(.down)
//
//        rightConstraint?.constant = newConstraint
//    }

    // MARK: - Asset loading

    override func assetDidChange(newAsset: AVAsset?) {
        super.assetDidChange(newAsset: newAsset)
        resetHandleViewPosition()
    }

    private func resetHandleViewPosition() {
        leftConstraint?.constant = 0
        rightConstraint?.constant = 0
        layoutIfNeeded()
    }

    // MARK: - Time Equivalence

    /// Move the position bar to the given time.
    public func seek(to time: CMTime) {
        if let newPosition = getPosition(from: time) {
            let offsetPosition = newPosition - assetPreview.contentOffset.x - leftHandleView.frame.origin.x
            let maxPosition = rightHandleView.frame.origin.x - (leftHandleView.frame.origin.x + handleWidth)
                              - positionBar.frame.width
            let normalizedPosition = min(max(0, offsetPosition), maxPosition)
            positionConstraint?.constant = normalizedPosition
            layoutIfNeeded()
        }
    }
  
    
    
    
//    public func getPositionRatio(at time: CMTime) -> CGFloat? {
//        let position = getPosition(from: time)!
//        return position  / durationSize
//
//    }
    
//    public func seekToPosition(at currentTime: CMTime) {
//        let newPosition = getPosition(from: currentTime)!
//        let offsetPosition = newPosition - assetPreview.contentOffset.x - leftHandleView.frame.origin.x
//        let maxPosition = rightHandleView.frame.origin.x - (leftHandleView.frame.origin.x + handleWidth)
//                          - positionBar.frame.width
//        let normalizedPosition = min(max(0, offsetPosition), maxPosition)
//        positionConstraint?.constant = normalizedPosition
//        layoutIfNeeded()
//    }
    
    
//    // Move left handle to specified time point
//    public func moveLeftHandle(to time: CMTime) {
//        if let updatedPosition = getPosition(from: time) {
//            updateLeftConstraintForTransition(
//                with: CGPoint(
//                    x: updatedPosition - (currentLeftConstraint * (frame.width / previousFrameWidth!)),
//                    y: 0)
//            )
//        }
//    }
//
//
//    // Move right handle to specified time point
//    public func moveRightHandle(to time: CMTime) {
//
//        if let updatedPosition = getPosition(from: time) {
//            updateRightConstraintForTransition(
//                with: CGPoint(
//                    x: updatedPosition - frame.width - (currentRightConstraint * (frame.width / previousFrameWidth!)) + (2 * handleWidth),
//                    y: 0)
//            )
//        }
//    }
    
    /// Move the left trimmer handle to the given time.
     public func moveLeftHandle(to time: CMTime) {
         if let newPosition = getPosition(from: time) {
             updateLeftConstraint(with: CGPoint(x: newPosition - currentLeftConstraint, y: 0))
             updateSelectedTime(stoppedMoving: false)
         }
     }

     /// Move the right trimmer handle to the given time.
     public func moveRightHandle(to time: CMTime) {
         if let newPosition = getPosition(from: time) {
             updateRightConstraint(with: CGPoint(x: newPosition - frame.width - currentRightConstraint + 2 * handleWidth, y: 0))
             updateSelectedTime(stoppedMoving: false)
         }
     }
    
//    public func updatePreviousFrameWidth() {
//        previousFrameWidth = frame.width
//    }
    
    
    // Move scroll view to ****
    
    
    

    /// The selected start time for the current asset.
    public var startTime: CMTime? {
        let startPosition = leftHandleView.frame.origin.x + assetPreview.contentOffset.x
        return getTime(from: startPosition)
    }

    /// The selected end time for the current asset.
    public var endTime: CMTime? {
        let endPosition = rightHandleView.frame.origin.x + assetPreview.contentOffset.x - handleWidth
        return getTime(from: endPosition)
    }

    private func updateSelectedTime(stoppedMoving: Bool) {
        guard let playerTime = positionBarTime else {
            return
        }
        if stoppedMoving {
            delegate?.positionBarStoppedMoving(playerTime)
        } else {
            delegate?.didChangePositionBar(playerTime)
        }
    }

    private var positionBarTime: CMTime? {
        let barPosition = positionBar.frame.origin.x + assetPreview.contentOffset.x - handleWidth
        return getTime(from: barPosition)
    }

    private var minimumDistanceBetweenHandle: CGFloat {
        guard let asset = asset else { return 0 }
        return CGFloat(minDuration) * assetPreview.contentView.frame.width / CGFloat(asset.duration.seconds)
    }

    // MARK: - Scroll View Delegate

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateSelectedTime(stoppedMoving: true)
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateSelectedTime(stoppedMoving: true)
        }
    }
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateSelectedTime(stoppedMoving: false)
    }
}
